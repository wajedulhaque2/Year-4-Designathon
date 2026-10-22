function result = clip_calibration_tests(position_mm,mass_g,bandsHz)
if nargin<1, position_mm = input('Movable clip position in mm: '); end
if nargin<2, mass_g = input('Total movable clip assembly mass in g: '); end
if nargin<3, bandsHz = [90 170; 260 410; 500 780]; end
assert(isscalar(position_mm) && ismember(position_mm,[56 112 140 168 224]),'Use one of the five clip markings.');
assert(isscalar(mass_g) && ismember(mass_g,[1.30 3.05]),'Use the weighed 1.30 g or 3.05 g assembly.');
assert(isnumeric(bandsHz) && size(bandsHz,2)==2 && ~isempty(bandsHz) && ...
    all(isfinite(bandsHz(:))) && all(bandsHz(:,1)>0) && ...
    all(bandsHz(:,2)<22050) && all(bandsHz(:,1)<bandsHz(:,2)) && ...
    all(bandsHz(2:end,1)>bandsHz(1:end-1,2)),'Use ordered, separate frequency ranges.');
fprintf('Calibration trial: %.2f g at %.0f mm; impact at 30 mm.\n',mass_g,position_mm);
sampleRate = 44100;
impactPosition_mm = 30;
modeBandsConfirmed = false;
maxStdHz = NaN;
skipSamples = round(0.01*sampleRate);
windowSamples = round(0.19*sampleRate);
fftLength = 8*windowSamples;
frequency = (0:fftLength-1)'*sampleRate/fftLength;
window = 0.5-0.5*cos(2*pi*(0:windowSamples-1)'/windowSamples);
peakCount = size(bandsHz,1);
recorder = audiorecorder(sampleRate,16,1);
result.sampleRate = sampleRate;
result.impactPosition_mm = impactPosition_mm;
result.bandsHz = bandsHz;
result.modeBandsConfirmed = modeBandsConfirmed;
result.repeatabilityLimitHz = maxStdHz;
result.recordings = cell(3,1);
result.impactTimeSeconds = NaN(3,1);
result.analysisRangeSeconds = NaN(3,2);
result.clipped = false(3,1);
result.peakToBackground = NaN(3,peakCount);
result.peakToMedian = NaN(3,peakCount);
values = NaN(3,peakCount);
quality = false(3,peakCount);
input('BACKGROUND: Enter, then remain quiet for 5 seconds. No drop. ', 's');
recordblocking(recorder,5);
background = getaudiodata(recorder);
result.background = background;
result.backgroundClipped = max(abs(background))>=0.98;
backgroundMean = mean(background);
background = background-backgroundMean;
triggerLevel = max(0.03,4*max(abs(background)));
result.triggerLevel = triggerLevel;
noiseSpectrum = zeros(fftLength,1);
for start = 1:windowSamples:length(background)-windowSamples+1
    segment = background(start:start+windowSamples-1);
    noiseSpectrum = max(noiseSpectrum,abs(fft((segment-mean(segment)).*window,fftLength)));
end
input('Keep the fixed reference attached and the chosen movable clip fitted. Enter. ', 's');
figure('Name','Clip measurement');
for drop = 1:3
    input(sprintf('Drop %d/3: Enter, then release ONCE within 1 second at 30 mm. ',drop),'s');
    recordblocking(recorder,5);
    recording = getaudiodata(recorder);
    result.recordings{drop} = recording;
    firstImpact = find(abs(recording-backgroundMean)>triggerLevel,1);
    if isempty(firstImpact) || firstImpact>round(1.25*sampleRate) || ...
            firstImpact+skipSamples+windowSamples-1>length(recording)
        fprintf('Drop %d: no usable early impact; recording retained.\n',drop);
        continue
    end
    first = firstImpact+skipSamples;
    last = first+windowSamples-1;
    ringing = recording(first:last);
    result.clipped(drop) = max(abs(ringing))>=0.98;
    result.impactTimeSeconds(drop) = (firstImpact-1)/sampleRate;
    result.analysisRangeSeconds(drop,:) = ([first last]-1)/sampleRate;
    spectrum = abs(fft((ringing-mean(ringing)).*window,fftLength));
    for mode = 1:peakCount
        bins = find(frequency>=bandsHz(mode,1) & frequency<=bandsHz(mode,2));
        [peak,localIndex] = max(spectrum(bins));
        values(drop,mode) = frequency(bins(localIndex));
        result.peakToBackground(drop,mode) = peak/max(max(noiseSpectrum(bins)),eps);
        result.peakToMedian(drop,mode) = peak/max(median(spectrum(bins)),eps);
        quality(drop,mode) = ~result.backgroundClipped && ~result.clipped(drop) && ...
            localIndex>1 && localIndex<length(bins) && ...
            result.peakToBackground(drop,mode)>4 && result.peakToMedian(drop,mode)>4;
    end
    fprintf('Drop %d candidate frequencies (Hz): ',drop);
    fprintf('%.2f ',values(drop,:)); fprintf('\n');
    if ~all(quality(drop,:))
        fprintf('Review required in region(s): %s.\n',mat2str(find(~quality(drop,:))));
    end
    subplot(2,1,1);
    plot((0:length(recording)-1)/sampleRate,recording);
    xline((first-1)/sampleRate,'g'); xline((last-1)/sampleRate,'r');
    xlim([0 1.6]); grid on;
    xlabel('Time (s)'); title('Only the green-to-red interval is analysed');
    subplot(2,1,2); plot(frequency,spectrum); hold on;
    for mode = 1:peakCount, xline(values(drop,mode),'--'); end
    hold off; xlim([max(0,min(bandsHz(:))-40),max(bandsHz(:))+40]); grid on;
    xlabel('Frequency (Hz)'); title('Candidate peaks in the selected frequency regions');
    drawnow;
end
result.trialsHz = values;
result.peakQuality = quality;
result.meanHz = mean(values,1);
result.stdHz = std(values,0,1);
result.signalPass = all(quality(:));
result.repeatabilityPass = isfinite(maxStdHz) && maxStdHz>0 && ...
    all(isfinite(result.stdHz)) && all(result.stdHz<=maxStdHz);
result.qualityPass = result.signalPass && result.repeatabilityPass;
fprintf('Mean candidate frequencies (Hz): '); fprintf('%.2f ',result.meanHz); fprintf('\n');
fprintf('Standard deviations (Hz): '); fprintf('%.2f ',result.stdHz); fprintf('\n');
if ~result.signalPass
    result.status = 'REVIEW_REQUIRED';
elseif ~modeBandsConfirmed
    result.status = 'MODE_IDENTITIES_UNCONFIRMED';
elseif ~isfinite(maxStdHz) || maxStdHz<=0
    result.status = 'REPEATABILITY_LIMIT_NOT_SET';
elseif ~result.repeatabilityPass
    result.status = 'REVIEW_REQUIRED';
else
    result.status = 'CANDIDATE_PEAKS';
end
result.knownPosition_mm = position_mm;
result.knownMass_g = mass_g;
result.candidateCalibrationRow = [position_mm mass_g result.meanHz result.stdHz];
result.approvedCalibrationRow = NaN(1,2+2*peakCount);
if result.qualityPass && modeBandsConfirmed && peakCount==3
    result.approvedCalibrationRow = result.candidateCalibrationRow;
    result.status = 'CALIBRATION_CANDIDATE';
end
fprintf('Candidate row: '); fprintf('%.6f ',result.candidateCalibrationRow); fprintf('\n');
result.savedFile = fullfile(pwd,sprintf('cal_%03dg_%dmm_%s.mat', ...
    round(100*mass_g),position_mm,datestr(now,'yyyymmdd_HHMMSSFFF')));
save(result.savedFile,'result');
fprintf('Status: %s\n',result.status);
fprintf('Saved: %s\n',result.savedFile);
end
