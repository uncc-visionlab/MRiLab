function rfAmpSum = BlochKernelNormalCPU(Gyro, CS, SpinNum, Rho, T1, T2, Mz, My, Mx, ...
    dB0, dWRnd, Gzgrid, Gygrid, Gxgrid, TxCoilmg, TxCoilpe, ...
    dt, rfAmp, rfPhase, rfFreq, GzAmp, GyAmp, GxAmp, ...
    Typei, SpinMxNum, SpinMxSliceNum, TxCoilNum)
%/* variables for dealing multi-Tx */
rfAmpSum = 0;
%rfAmpBuf;
%rfPhaseBuf;
%rfFreqBuf;

%/* Calculate dW */
buffer = zeros(1, SpinMxNum, 'single');
buffer1 = zeros(1, SpinMxNum, 'single');
buffer2 = zeros(1, SpinMxNum, 'single');
buffer3 = zeros(1, SpinMxNum, 'single');
buffer4 = zeros(1, SpinMxNum, 'single');
buffer5 = zeros(1, SpinMxNum, 'single');
buffer6 = zeros(1, SpinMxNum, 'single');
SinAlpha = zeros(1, SpinMxNum, 'single');
SinBeta = zeros(1, SpinMxNum, 'single');
CosAlpha = zeros(1, SpinMxNum, 'single');
CosBeta = zeros(1, SpinMxNum, 'single');
CosPhi = zeros(1, SpinMxNum, 'single');
SinPhi = zeros(1, SpinMxNum, 'single');
minusCosPhi = zeros(1, SpinMxNum, 'single');
minusSinPhi = zeros(1, SpinMxNum, 'single');
dW = zeros(1, SpinMxNum, 'single');
alpha = zeros(1, SpinMxNum, 'single');
beta = zeros(1, SpinMxNum, 'single');

% ippsMulC_32f(dB0, Gyro, dW, SpinMxNum); /* add dw caused by main field imhomogeneity */
dW = dB0*Gyro; %  /* add dw caused by main field imhomogeneity */

% ippsAdd_32f_I(dWRnd, dW, SpinMxNum); /* add dWRnd for simulating T2* effect */
dW = dW + dWRnd; % /* add dWRnd for simulating T2* effect */
% ippsAddC_32f_I((float)(CS[Typei]) * 2 * PI, dW, SpinMxNum); /* add dw caused by chemical shift */
dW = dW + CS(Typei+1)*2*pi;
% ippsMulC_32f(Gzgrid, (GzAmp) * (Gyro), buffer, SpinMxNum);
buffer = Gzgrid*(GzAmp*Gyro);
% ippsAdd_32f_I(buffer, dW, SpinMxNum); /* add dw caused by Gz for space encoding */
buffer = buffer + dW; % /* add dw caused by Gz for space encoding */
% ippsMulC_32f(Gygrid, (GyAmp) * (Gyro), buffer, SpinMxNum);
buffer = Gygrid*(GyAmp*Gyro);
% ippsAdd_32f_I(buffer, dW, SpinMxNum); /* add dw caused by Gy for space encoding */
dW = dW + buffer; % /* add dw caused by Gy for space encoding */
% ippsMulC_32f(Gxgrid, (GxAmp) * (Gyro), buffer, SpinMxNum);
buffer = Gxgrid*(GxAmp*Gyro);
% ippsAdd_32f_I(buffer, dW, SpinMxNum); /* add dw caused by Gx for space encoding */
dW = dW + buffer; % /* add dw caused by Gx for space encoding */

% /* Spin process */
for i=0:(TxCoilNum-1)
    rfAmpSum=rfAmpSum + abs(rfAmp(i+1));
end

if (rfAmpSum ~= 0)
    if (TxCoilNum == 1)
        rfAmpBuf   = rfAmp(1);
        rfPhaseBuf = rfPhase(1);
        rfFreqBuf  = rfFreq(1); % /* note rfFreq is defined as fB0-frf */
        if (rfAmpBuf<0)
            rfAmpBuf=abs(rfAmpBuf);
            rfPhaseBuf=rfPhaseBuf+pi;
        end
        
        % ippsMulC_32f(TxCoilmg, rfAmpBuf, buffer1, SpinMxNum);   /* deal with B1+ magnitude */
        buffer1 = TxCoilmg.*rfAmpBuf;
        % ippsAddC_32f(TxCoilpe, rfPhaseBuf, buffer2, SpinMxNum); /* deal with B1+ phase*/
        buffer2 = TxCoilpe + rfPhaseBuf;
        % ippsAddC_32f_I(rfFreqBuf * 2 * PI, dW, SpinMxNum); /* add dw caused by off-resonance rf effect */
        dW = dW + rfFreqBuf * 2 * pi;
        % ippsMulC_32f_I(Gyro, buffer1, SpinMxNum);
        buffer1 = buffer1*Gyro;
        % ippsMulC_32f_I(-1, buffer2, SpinMxNum);
        buffer2 = -1*buffer2;
    else
        % ippsZero_32f(buffer5, SpinMxNum);
        buffer5 = 0;
        % ippsZero_32f(buffer6, SpinMxNum);
        buffer6 = 0;
        for i=0:(TxCoilNum-1) % /* multi-Tx,  sum all (B1+ * rf) */
            rfAmpBuf   = rfAmp(i+1);
            rfPhaseBuf = rfPhase(i+1);
            rfFreqBuf  = rfFreq(i+1); % /* note rfFreq is defined as fB0-frf */
            if (rfAmpBuf ~=0 )
                if (rfAmpBuf<0)
                    rfAmpBuf=abs(rfAmpBuf);
                    rfPhaseBuf=rfPhaseBuf+pi;
                end
                
                % ippsMulC_32f(TxCoilmg + i * SpinMxSliceNum * SpinMxNum, rfAmpBuf, buffer1, SpinMxNum);   /* deal with B1+ magnitude */
                % ippsAddC_32f(TxCoilpe + i * SpinMxSliceNum * SpinMxNum, rfPhaseBuf, buffer2, SpinMxNum); /* deal with B1+ phase*/
                
                % #ifdef IPP
                % ippsPolarToCart_32f(buffer1, buffer2, buffer3, buffer4, SpinMxNum);
                % ippsAdd_32f_I(buffer3, buffer5, SpinMxNum); /* add real from multi-Tx */
                % ippsAdd_32f_I(buffer4, buffer6, SpinMxNum); /* add imag from multi-Tx */
                % ippsAddC_32f_I(rfFreqBuf * 2 * PI, dW, SpinMxNum); /* add dw caused by off-resonance rf effect */
            end
        end
        
        % ippsCartToPolar_32f(buffer5, buffer6, buffer1, buffer2, SpinMxNum); /* buffer1 is mag, buffer2 is phase*/
        
        % #endif
        
        % #ifdef FW
        % fwsCos_32f_A24 (buffer2, buffer3, SpinMxNum);
        % fwsSin_32f_A24 (buffer2, buffer4, SpinMxNum);
        % fwsMul_32f_I(buffer1, buffer3, SpinMxNum);
        % fwsMul_32f_I(buffer1, buffer4, SpinMxNum);
        % fwsAdd_32f_I(buffer3, buffer5, SpinMxNum); /* add real from multi-Tx */
        % fwsAdd_32f_I(buffer4, buffer6, SpinMxNum); /* add imag from multi-Tx */
        % fwsAddC_32f_I(rfFreqBuf * 2 * PI, dW, SpinMxNum); /* add dw caused by off-resonance rf effect */
        % end
        % end
        % fwsAtan2_32f_A24(buffer6, buffer5, buffer2, SpinMxNum); /* buffer2 is phase */
        % fwsSqr_32f_I(buffer5, SpinMxNum);
        % fwsSqr_32f_I(buffer6, SpinMxNum);
        % fwsAdd_32f_I(buffer5, buffer6, SpinMxNum);
        % fwsSqrt_32f(buffer6, buffer1, SpinMxNum); /* buffer1 is mag */
        
        % #endif
        
        % ippsMulC_32f_I(Gyro, buffer1, SpinMxNum);
        buffer1 = Gyro * buffer1;
        % ippsMulC_32f_I(-1, buffer2, SpinMxNum);
        buffer2 = -1 * buffer2;
    end
    
    % /* Calculate beta */
    % ippsDiv_32f(buffer1, dW, buffer, SpinMxNum);
    buffer  = dW ./ buffer1;
    % ippsArctan_32f(buffer, beta, SpinMxNum);
    beta = atan(buffer);
    % /* Calculate alpha */
    % ippsSqr_32f(dW, buffer, SpinMxNum);
    buffer = dW.^2;
    % ippsSqr_32f_I(buffer1, SpinMxNum);
    buffer1 = buffer1.^2;
    % ippsAdd_32f_I(buffer1, buffer, SpinMxNum);
    buffer = buffer + buffer1;
    % ippsSqrt_32f_I(buffer, SpinMxNum);
    buffer = sqrt(buffer);
    % ippsMulC_32f(buffer, dt, alpha, SpinMxNum);
    alpha = buffer*dt;
    % /* Trigonometry */
    % ippsSin_32f_A24 (alpha, SinAlpha, SpinMxNum);
    % ippsSin_32f_A24 (beta, SinBeta, SpinMxNum);
    % ippsCos_32f_A24 (alpha, CosAlpha, SpinMxNum);
    % ippsCos_32f_A24 (beta, CosBeta, SpinMxNum);
    
    % ippsSin_32f_A24 (buffer2, SinPhi, SpinMxNum);
    % ippsMulC_32f(SinPhi, -1, minusSinPhi, SpinMxNum);
    % ippsCos_32f_A24 (buffer2, CosPhi, SpinMxNum);
    % ippsMulC_32f(CosPhi, -1, minusCosPhi, SpinMxNum);
    
    % /* Calculate Mx */
    
    % ippsMul_32f(SinBeta, CosAlpha, buffer1, SpinMxNum);
    % ippsMul_32f_I(minusCosPhi, buffer1, SpinMxNum);
    % ippsMul_32f(SinAlpha, SinPhi, buffer3, SpinMxNum);
    % ippsAdd_32f_I(buffer3, buffer1, SpinMxNum);
    % ippsMul_32f_I(SinBeta, buffer1, SpinMxNum);
    % ippsMulC_32f_I(-1, buffer1, SpinMxNum);
    % ippsSqr_32f(CosBeta, buffer3, SpinMxNum);
    % ippsMul_32f_I(CosPhi, buffer3, SpinMxNum);
    % ippsAdd_32f_I(buffer3, buffer1, SpinMxNum);
    % ippsCopy_32f(buffer1, buffer3, SpinMxNum);
    
    % ippsMul_32f_I(CosPhi, buffer1, SpinMxNum);
    % ippsMul_32f_I(SinPhi, buffer3, SpinMxNum);
    
    % ippsMul_32f(SinAlpha, SinBeta, buffer2, SpinMxNum);
    % ippsMul_32f_I(CosPhi, buffer2, SpinMxNum);
    % ippsMul_32f(CosAlpha,SinPhi,buffer4, SpinMxNum);
    % ippsAdd_32f_I(buffer4, buffer2, SpinMxNum);
    % ippsCopy_32f(buffer2, buffer4, SpinMxNum);
    
    % ippsMul_32f_I(SinPhi,buffer2, SpinMxNum);
    % ippsMul_32f_I(minusCosPhi, buffer4, SpinMxNum);
    
    
    % ippsAdd_32f_I(buffer1, buffer2, SpinMxNum);
    % ippsMul_32f_I(Mx, buffer2, SpinMxNum);
    
    % ippsAdd_32f_I(buffer3, buffer4, SpinMxNum);
    % ippsMul_32f_I(My, buffer4, SpinMxNum);
    % ippsMulC_32f_I(-1, buffer4, SpinMxNum);
    
    % ippsAdd_32f(buffer2, buffer4, buffer, SpinMxNum);
    
    
    % ippsMul_32f(SinBeta, CosBeta, buffer1, SpinMxNum);
    % ippsMul_32f_I(CosPhi, buffer1, SpinMxNum);
    
    % ippsMul_32f(SinBeta, CosAlpha, buffer2, SpinMxNum);
    % ippsMul_32f_I(minusCosPhi, buffer2, SpinMxNum);
    
    % ippsMul_32f(SinAlpha, SinPhi, buffer3, SpinMxNum);
    
    % ippsAdd_32f_I(buffer3, buffer2, SpinMxNum);
    % ippsMul_32f_I(CosBeta, buffer2, SpinMxNum);
    
    % ippsAdd_32f_I(buffer2, buffer1, SpinMxNum);
    % ippsMul_32f_I(Mz, buffer1, SpinMxNum);
    
    % ippsAdd_32f(buffer, buffer1, alpha, SpinMxNum); /* use the space of alpha as buffer for storing Mx */
    
    
    % /*
    % Mx*(cos(PHI)*(cos(BETA)^2*cos(PHI) - sin(BETA)*(sin(ALPHA)*sin(PHI) - cos(ALPHA)*cos(PHI)*sin(BETA))) + sin(PHI)*(cos(ALPHA)*sin(PHI) + cos(PHI)*sin(ALPHA)*sin(BETA)))
    % - My*(sin(PHI)*(cos(BETA)^2*cos(PHI) - sin(BETA)*(sin(ALPHA)*sin(PHI) - cos(ALPHA)*cos(PHI)*sin(BETA))) - cos(PHI)*(cos(ALPHA)*sin(PHI) + cos(PHI)*sin(ALPHA)*sin(BETA)))
    % + Mz*(cos(BETA)*(sin(ALPHA)*sin(PHI) - cos(ALPHA)*cos(PHI)*sin(BETA)) + cos(BETA)*cos(PHI)*sin(BETA))
    % */
    
    % /* Calculate My */
    
    
    % ippsMul_32f(CosAlpha, SinBeta, buffer1, SpinMxNum);
    % ippsMul_32f_I(SinPhi,buffer1, SpinMxNum);
    % ippsMul_32f(SinAlpha,CosPhi, buffer3, SpinMxNum);
    % ippsAdd_32f_I(buffer3, buffer1, SpinMxNum);
    % ippsMul_32f_I(SinBeta, buffer1, SpinMxNum);
    % ippsSqr_32f(CosBeta, buffer3, SpinMxNum);
    % ippsMul_32f_I(SinPhi, buffer3, SpinMxNum);
    % ippsAdd_32f_I(buffer3, buffer1, SpinMxNum);
    % ippsCopy_32f(buffer1, buffer3, SpinMxNum);
    
    % ippsMul_32f_I(SinPhi, buffer1, SpinMxNum);
    % ippsMul_32f_I(CosPhi, buffer3, SpinMxNum);
    
    % ippsMul_32f(SinAlpha, SinBeta, buffer2, SpinMxNum);
    % ippsMul_32f_I(minusSinPhi, buffer2, SpinMxNum);
    % ippsMul_32f(CosAlpha, CosPhi, buffer4, SpinMxNum);
    % ippsAdd_32f_I(buffer4, buffer2, SpinMxNum);
    % ippsCopy_32f(buffer2, buffer4, SpinMxNum);
    
    % ippsMul_32f_I(CosPhi,buffer2, SpinMxNum);
    % ippsMul_32f_I(minusSinPhi, buffer4, SpinMxNum);
    
    % ippsAdd_32f_I(buffer1, buffer2, SpinMxNum);
    % ippsMul_32f_I(My, buffer2, SpinMxNum);
    
    % ippsAdd_32f_I(buffer3, buffer4, SpinMxNum);
    % ippsMul_32f_I(Mx, buffer4, SpinMxNum);
    % ippsMulC_32f_I(-1, buffer4, SpinMxNum);
    
    % ippsAdd_32f(buffer2, buffer4, buffer, SpinMxNum);
    
    
    % ippsMul_32f(CosBeta, SinBeta, buffer1, SpinMxNum);
    % ippsMul_32f_I(minusSinPhi, buffer1, SpinMxNum);
    
    % ippsMul_32f(CosAlpha, SinBeta, buffer2, SpinMxNum);
    % ippsMul_32f_I(SinPhi, buffer2, SpinMxNum);
    
    % ippsMul_32f(SinAlpha, CosPhi, buffer3, SpinMxNum);
    
    % ippsAdd_32f_I(buffer3, buffer2, SpinMxNum);
    % ippsMul_32f_I(CosBeta, buffer2, SpinMxNum);
    
    % ippsAdd_32f_I(buffer2, buffer1, SpinMxNum);
    % ippsMul_32f_I(Mz, buffer1, SpinMxNum);
    
    % ippsAdd_32f(buffer, buffer1, beta, SpinMxNum); /* use the space of beta as buffer for storing My */
    
    
    % /*
    % My*(sin(PHI)*(sin(PHI)*cos(BETA)^2 + sin(BETA)*(cos(PHI)*sin(ALPHA) + cos(ALPHA)*sin(BETA)*sin(PHI))) + cos(PHI)*(cos(ALPHA)*cos(PHI) - sin(ALPHA)*sin(BETA)*sin(PHI)))
    % - Mx*(cos(PHI)*(sin(PHI)*cos(BETA)^2 + sin(BETA)*(cos(PHI)*sin(ALPHA) + cos(ALPHA)*sin(BETA)*sin(PHI))) - sin(PHI)*(cos(ALPHA)*cos(PHI) - sin(ALPHA)*sin(BETA)*sin(PHI)))
    % + Mz*(cos(BETA)*(cos(PHI)*sin(ALPHA) + cos(ALPHA)*sin(BETA)*sin(PHI)) - cos(BETA)*sin(BETA)*sin(PHI))
    % */
    
    % /*Calculate Mz */
    
    % ippsMul_32f(CosAlpha, CosBeta, buffer1, SpinMxNum);
    % ippsMul_32f_I(SinBeta, buffer1, SpinMxNum);
    % ippsMulC_32f_I(-1, buffer1, SpinMxNum);
    
    % ippsMul_32f(CosBeta, SinBeta, buffer3, SpinMxNum);
    % ippsAdd_32f_I(buffer3, buffer1, SpinMxNum);
    % ippsCopy_32f(buffer1, buffer3, SpinMxNum);
    
    % ippsMul_32f_I(CosPhi, buffer1, SpinMxNum);
    % ippsMul_32f_I(SinPhi, buffer3, SpinMxNum);
    
    % ippsMul_32f(CosBeta, SinAlpha, buffer2, SpinMxNum);
    % ippsMul_32f_I(minusSinPhi, buffer2, SpinMxNum);
    
    % ippsMul_32f(CosBeta, SinAlpha, buffer4, SpinMxNum);
    % ippsMul_32f_I(CosPhi, buffer4, SpinMxNum);
    
    % ippsAdd_32f_I(buffer1, buffer2, SpinMxNum);
    % ippsMul_32f_I(Mx, buffer2, SpinMxNum);
    
    % ippsAdd_32f_I(buffer3, buffer4, SpinMxNum);
    % ippsMul_32f_I(My, buffer4, SpinMxNum);
    % ippsMulC_32f_I(-1, buffer4, SpinMxNum);
    
    % ippsAdd_32f(buffer2, buffer4, buffer, SpinMxNum);
    
    % ippsSqr_32f(SinBeta, buffer1, SpinMxNum);
    
    % ippsSqr_32f(CosBeta, buffer2, SpinMxNum);
    % ippsMul_32f_I(CosAlpha, buffer2, SpinMxNum);
    
    % ippsAdd_32f_I(buffer2, buffer1, SpinMxNum);
    % ippsMul_32f_I(Mz, buffer1, SpinMxNum);
    
    % ippsAdd_32f(buffer, buffer1, dW, SpinMxNum); /* use the space of dW as buffer for storing Mz */
    
    
    % /*
    % Mx*(cos(PHI)*(cos(BETA)*sin(BETA) - cos(ALPHA)*cos(BETA)*sin(BETA)) - cos(BETA)*sin(ALPHA)*sin(PHI))
    % - My*(sin(PHI)*(cos(BETA)*sin(BETA) - cos(ALPHA)*cos(BETA)*sin(BETA)) + cos(BETA)*cos(PHI)*sin(ALPHA))
    % + Mz*(cos(ALPHA)*cos(BETA)^2 + sin(BETA)^2)
    % */
    
    % ippsCopy_32f(alpha, Mx, SpinMxNum);
    % ippsCopy_32f(beta, My, SpinMxNum);
    % ippsCopy_32f(dW, Mz, SpinMxNum);
    
    
else
    % /* Calculate alpha */
    % ippsMulC_32f(dW, dt, alpha, SpinMxNum);
    
    % ippsSin_32f_A24 (alpha, SinAlpha, SpinMxNum);
    % ippsCos_32f_A24 (alpha, CosAlpha, SpinMxNum);
    
    
    % /* Calculate Mx */
    % ippsMul_32f(Mx, CosAlpha, buffer1, SpinMxNum);
    % ippsMul_32f(My, SinAlpha, buffer2, SpinMxNum);
    % ippsAdd_32f(buffer1, buffer2, alpha, SpinMxNum); /* use the space of alpha as buffer for storing Mx */
    
    
    % /* Calculate My */
    % ippsMul_32f(My, CosAlpha, buffer3, SpinMxNum);
    % ippsMul_32f(Mx, SinAlpha, buffer4, SpinMxNum);
    % ippsMulC_32f_I(-1, buffer4, SpinMxNum);
    % ippsAdd_32f(buffer3, buffer4, beta, SpinMxNum); /* use the space of beta as buffer for storing My */
    
    % /*
    % Mx*cos(ALPHA) + My*sin(ALPHA)
    %
    % My*cos(ALPHA) - Mx*sin(ALPHA)
    %
    % Mz
    % */
    % ippsCopy_32f(alpha, Mx, SpinMxNum);
    % ippsCopy_32f(beta, My, SpinMxNum);
    
end

% /* Relax */

% ippsInv_32f_A24(T2, buffer1, SpinMxNum);
% ippsMulC_32f_I(dt, buffer1, SpinMxNum);
% ippsMulC_32f_I(-1, buffer1, SpinMxNum);
% ippsThreshold_LT_32f_I(buffer1, SpinMxNum, -200);/* Prevent -1.#IND error (i.e. overflow caused by following exp) */
% ippsExp_32f_I(buffer1, SpinMxNum);

% ippsInv_32f_A24(T1, buffer2, SpinMxNum);
% ippsMulC_32f_I(dt, buffer2, SpinMxNum);
% ippsMulC_32f_I(-1, buffer2, SpinMxNum);
% ippsThreshold_LT_32f_I(buffer2, SpinMxNum, -200);/* Prevent -1.#IND error (i.e. overflow caused by following exp) */
% ippsExp_32f_I(buffer2, SpinMxNum);

% ippsMul_32f_I(buffer1, Mx, SpinMxNum);
% ippsMul_32f_I(buffer1, My, SpinMxNum);

% ippsMulC_32f(buffer2, -1, buffer3, SpinMxNum);
% ippsAddC_32f_I(1, buffer3, SpinMxNum);
% ippsDivC_32f(Rho, *SpinNum, buffer4, SpinMxNum);
% ippsMul_32f_I(buffer4, buffer3, SpinMxNum);
% ippsMul_32f(Mz, buffer2, buffer4 ,SpinMxNum);
% ippsAdd_32f(buffer3, buffer4, Mz, SpinMxNum);

% /*
%                                     Mx/exp(dt/T2)
%                                     My/exp(dt/T2)
%  Mz/exp(dt/T1) - (Rho*(1/exp(dt/T1) - 1))/SpinNum
% */


% /* Free memory */
% ippsFree(buffer);
% ippsFree(buffer1);
% ippsFree(buffer2);
% ippsFree(buffer3);
% ippsFree(buffer4);
% ippsFree(buffer5);
% ippsFree(buffer6);
% ippsFree(SinAlpha);
% ippsFree(SinBeta);
% ippsFree(SinPhi);
% ippsFree(minusSinPhi);
% ippsFree(CosAlpha);
% ippsFree(CosBeta);
% ippsFree(CosPhi);
% ippsFree(minusCosPhi);
% ippsFree(dW);
% ippsFree(alpha);
% ippsFree(beta);
end