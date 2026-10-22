function result = clip_student(action)
if nargin<1, action = 'find'; end
assert(ismember(action,{'find','measure','spectrum'}),'Use find, measure or spectrum.');
bandsHz = [90 170; 260 410; 500 780];
matchLimitHz = NaN;
validated = false;
calibration = [
    56 1.30 NaN NaN NaN NaN NaN NaN;
    56 3.05 NaN NaN NaN NaN NaN NaN;
    112 1.30 NaN NaN NaN NaN NaN NaN;
    112 3.05 NaN NaN NaN NaN NaN NaN;
    140 1.30 NaN NaN NaN NaN NaN NaN;
    140 3.05 NaN NaN NaN NaN NaN NaN;
    168 1.30 NaN NaN NaN NaN NaN NaN;
    168 3.05 NaN NaN NaN NaN NaN NaN;
    224 1.30 NaN NaN NaN NaN NaN NaN;
    224 3.05 NaN NaN NaN NaN NaN NaN
];
disp('Three-mode identification is incomplete. Candidate peaks will be recorded.');
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
result.position_mm = NaN;
result.mass_g = NaN;
result.validated = validated;
if strcmp(action,'spectrum')
    result.status = 'SPECTRUM_ONLY';
elseif strcmp(action,'find') && result.qualityPass && modeBandsConfirmed
    ready = size(calibration,2)==8 && size(calibration,1)>=2 && ...
        all(isfinite(calibration(:))) && isfinite(matchLimitHz) && matchLimitHz>0;
    if ~ready
        result.status = 'CALIBRATION_INCOMPLETE';
    elseif any(any(calibration(:,6:8)<0)) || any(any(calibration(:,6:8)>maxStdHz))
        result.status = 'CALIBRATION_REVIEW_REQUIRED';
    else
        overlap = false;
        for a = 1:size(calibration,1)-1
            for b = a+1:size(calibration,1)
                overlap = overlap || norm(calibration(a,3:5)-calibration(b,3:5))/sqrt(3)<=2*matchLimitHz;
            end
        end
        if overlap
            result.status = 'CALIBRATION_OVERLAP';
        else
            result.errorsHz = sqrt(mean(bsxfun(@minus,calibration(:,3:5),result.meanHz).^2,2));
            rows = find(result.errorsHz<=matchLimitHz);
            result.status = 'UNCERTAIN';
            if numel(rows)==1
                result.candidate = calibration(rows,1:2);
                result.status = 'UNVALIDATED';
                if validated
                    result.position_mm = result.candidate(1);
                    result.mass_g = result.candidate(2);
                    result.status = 'TABLE_MATCH';
                end
            end
        end
    end
end
result.savedFile = fullfile(pwd,['student_' datestr(now,'yyyymmdd_HHMMSSFFF') '.mat']);
save(result.savedFile,'result');
fprintf('Status: %s\n',result.status);
fprintf('Saved: %s\n',result.savedFile);
if isfinite(result.position_mm)
    fprintf('Position: %.0f mm; mass: %.2f g.\n',result.position_mm,result.mass_g);
end
end
