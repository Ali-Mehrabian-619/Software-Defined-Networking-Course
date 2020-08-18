EB=-5:0.5:15;
%%
parfor i=1:41
    
[ber, numBits]=BER_measure(EB(1,i),5e7,5e7,1,1)

BER_1_QPSK(1,i)=ber;

    
end



%%


parfor i=1:41
    
[ber, numBits]=BER_measure(EB(1,i),5e7,5e7,2,1)

BER_2_QPSK(1,i)=ber;

    
end
%%

parfor i=1:41
    
[ber, numBits]=BER_measure(EB(1,i),5e7,5e7,3,1)

BER_3_QPSK(1,i)=ber;

    
end
%%
parfor i=1:41
    
[ber, numBits]=BER_measure(EB(1,i),5e7,5e7,4,1)

BER_4_QPSK(1,i)=ber;

    
end
%%
parfor i=1:41
    
[ber, numBits]=BER_measure(EB(1,i),5e7,5e7,5,1)

BER_5_QPSK(1,i)=ber;

    
end
%%
parfor i=1:41
    
[ber, numBits]=BER_measure(EB(1,i),5e7,5e7,6,1)

BER_6_QPSK(1,i)=ber;

    
end

%%
function y=Modulator(u, Mode)


QPSK = comm.PSKModulator(4, 'BitInput', true, ...
'PhaseOffset', pi/4, 'SymbolMapping', 'Custom', ...
'CustomSymbolMapping', [0 2 3 1]);

QAM16 = comm.RectangularQAMModulator(16, 'BitInput',true,...
'NormalizationMethod','Average power','SymbolMapping','Custom',...
'CustomSymbolMapping',[11 10 14 15 9 8 12 13 1 0 4 5 3 2 6 7]);

QAM64 = comm.RectangularQAMModulator('ModulationOrder',64,'BitInput',true);



switch Mode
case 1
y=step(QPSK, u);
case 2
y=step(QAM16, u);
case 3
y=step(QAM64, u);
end

end

function y=DemodulatorSoft(u, Mode, NoiseVar)

QPSK = comm.PSKDemodulator(...
'ModulationOrder', 4, ...
'BitOutput', true, ...
'PhaseOffset', pi/4, 'SymbolMapping', 'Custom', ...
'CustomSymbolMapping', [0 2 3 1],...
'DecisionMethod', 'Approximate log-likelihood ratio', ...
'VarianceSource', 'Input port');

QAM16 = comm.RectangularQAMDemodulator(...
'ModulationOrder', 16, ...
'BitOutput', true, ...
'NormalizationMethod', 'Average power', 'SymbolMapping', 'Custom', ...
'CustomSymbolMapping', [11 10 14 15 9 8 12 13 1 0 4 5 3 2 6 7],...
'DecisionMethod', 'Approximate log-likelihood ratio', ...
'VarianceSource', 'Input port');
QAM64 = comm.RectangularQAMDemodulator(...
'ModulationOrder', 64, ...
'BitOutput', true, ...
'NormalizationMethod', 'Average power', 'SymbolMapping', 'Custom', ...
'CustomSymbolMapping', ...
[47 46 42 43 59 58 62 63 45 44 40 41 57 56 60 61 37 36 32 33 ...
49 48 52 53 39 38 34 35 51 50 54 55 7 6 2 3 19 18 22 23 5 4 0 1 ...
17 16 20 21 13 12 8 9 25 24 28 29 15 14 10 11 27 26 30 31],...
'DecisionMethod', 'Approximate log-likelihood ratio', ...
'VarianceSource', 'Input port');


switch Mode
case 1
y=step(QPSK, u, NoiseVar);
case 2
y=step(QAM16,u, NoiseVar);
case 3
y=step(QAM64, u, NoiseVar);
otherwise
error('Invalid Modulation Mode. Use {1,2, or 3}');
end
end

function y=TurboEncoder(u, lteIntrlvrIndices)
%#codegen

Turbo = comm.TurboEncoder('TrellisStructure', poly2trellis(4, [13 15], 13), ...
'InterleaverIndicesSource','Input port');

y=step(Turbo, u, lteIntrlvrIndices);
end

function y=TurboDecoder(u, lteIntrlvrIndices, maxIter)

Turbo = comm.TurboDecoder('TrellisStructure', poly2trellis(4, [13 15], 13),...
'InterleaverIndicesSource','Input port', ...
'NumIterations', maxIter);

y=step(Turbo, u, lteIntrlvrIndices);
end


function [y, flag, iters]=TurboDecoder_crc(u,lteIntrlvrIndices,m)
%#codegen
MAXITER=m;

Turbo = commLTETurboDecoder('InterleaverIndicesSource', 'Input port', ...
'MaximumIterations', MAXITER);

[y, flag, iters] = step(Turbo, u, lteIntrlvrIndices);

end

function y = CbCRCDetector(u)
%#codegen

hTBCRC = comm.CRCDetector('Polynomial', [1 1 zeros(1, 16) 1 1 0 0 0 1 1]);

% Transport block CRC generation
y = step(hTBCRC, u);
end

function y = CbCRCGenerator(u)

hTBCRCGen = comm.CRCGenerator('Polynomial',[1 1 zeros(1, 16) 1 1 0 0 0 1 1]);

% Transport block CRC generation
y = step(hTBCRCGen, u);
end

function y = cd(u)
%#codegen

hTBCRC = comm.CRCDetector('Polynomial', [1 1 zeros(1, 16) 1 1 0 0 0 1 1]);

% Transport block CRC generation
y = step(hTBCRC, u);
end


function [ber, numBits]=BER_measure(EbNo, maxNumErrs, maxNumBits,m,k)

FRM=2048; 
Kplus=FRM+24;
BitError = comm.ErrorRate;
%Indices = lteIntrlvrIndices(Kplus);

if k==1
    a='QPSK';
    
elseif k==2
    
    a='16QAM';
    
elseif k==3
    
    a='64QAM';
    
end


maxIter=6;
CodingRate=Kplus/(3*Kplus+12);
snr = EbNo + 10*log10(k) + 10*log10(CodingRate);
noiseVar = 10.^(-snr/10);
Hist=dsp.Histogram('LowerLimit', 1, 'UpperLimit', maxIter, 'NumBins', maxIter,'RunningHistogram', true);

numErrs = 0; numBits = 0; nS=0;
while ((numErrs < maxNumErrs) && (numBits < maxNumBits))
% Transmitter
u = randi([0 1], FRM,1); 
data= CbCRCGenerator(u); 
t0 = lteTurboEncode(u); 

t2 =lteSymbolModulate(t0,a); 


% Channel
c0 = awgn(t2, snr); % AWGN channel

% Receiver
r0 = lteSymbolDemodulate(c0,a,'Soft');

y = lteTurboDecode(r0,m); 

numErrs = numErrs + sum(~(y)==u); 
numBits = numBits + FRM; 



end

ber = numErrs/numBits; 

end










