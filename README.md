# Where's the Clip?

We built a small beam-vibration kit for a Dynamics and Control student activity. The idea was to hide a clip on an aluminium beam, measure its first three bending-mode frequencies and use an experimental calibration table to identify the clip's mass and position.

We didn't get the prototype to that point. We recorded all ten clip configurations and found some repeatable higher-frequency features, but we couldn't reliably identify the first three bending modes. The code is here with the unfinished calibration values left visible. It can record and analyse an attempt, but the current version will withhold mass-and-position identification.

## Files

| File | Purpose |
| --- | --- |
| `clip_student.m` | Student measurement workflow and the intended three-frequency identification step. The calibration table is inside this file. |
| `clip_calibration_tests.m` | The same recording and peak-analysis procedure, with a known clip mass and position supplied for a calibration trial. |
| `README.md` | Setup, student instructions, testing history and what remains unfinished. |

Both MATLAB files are standalone and contain no comments. No separate spreadsheet or CSV is required. These are cleaned-up versions of the development workflow; they are not a claim that the final source files have passed a live MATLAB test.

## The setup

The rig uses a 280 x 25 x 2 mm aluminium beam on foam supports, a fixed reference clip, a movable clip, a guided ball drop and a laptop microphone.

| Setting | Value |
| --- | --- |
| Ball-impact point | **30 mm from the left end**, for every drop |
| Movable-clip markings | 56, 112, 140, 168 and 224 mm from the left end |
| Empty movable assembly | 1.30 g |
| Weighted movable assembly | 3.05 g |
| Drops per fitted configuration | Three |
| Fixed reference | Attached throughout the clip trials |

The ball-impact point and the movable-clip position are different measurements. The ball stays at 30 mm while the clip moves between the five markings. An empty clip still adds 1.30 g; it is not a clip-free baseline. This workflow does not ask for a separate set of clip-off drops before every configuration.

Earlier planning referred to a 20 mm impact point. The practical position was corrected to 30 mm because 20 mm was not achievable on the rig. Use 30 mm throughout.

## A typical student run

### 1. Open the files in MATLAB

Download the repository and extract it into a folder where you can save files. Open MATLAB and set that folder as the Current Folder. Keep the `.m` filenames unchanged so MATLAB can find the functions.

Use MATLAB R2019a or later with working audio input. The code uses base MATLAB functions and does not require the Signal Processing Toolbox. It records from the computer's default microphone, so check the operating system's selected input before starting.

### 2. Prepare the apparatus

Keep the fixed reference attached. Fit either the empty or weighted movable clip at one of the five markings. For an intended blind trial, a partner would choose that configuration without telling the operator. The present prototype can demonstrate the recording procedure, but cannot yet return a validated identification.

Keep the supports, microphone position, cover arrangement and ball-drop height fixed. Set the guide to the **30 mm impact point**. Keep microphone enhancements and noise suppression off, as in the development tests, and use an input level that avoids clipping.

### 3. Start the measurement

In the Command Window, run:

```matlab
clear clip_student
R = clip_student;
```

The opening message explains that three-mode identification is incomplete. Leave the `NaN` values and validation flags unchanged for this prototype demonstration.

### 4. Record the background

At the background prompt, press Enter and remain quiet for five seconds. Do not release the ball or touch the apparatus during this recording.

At the next prompt, check that the reference and chosen movable clip are fitted, then press Enter.

### 5. Make three drops

At `Drop 1/3`, press Enter and release the ball once within one second, at the fixed 30 mm point. Let the five-second recording finish. Repeat when prompted for drops 2 and 3, keeping the same clip fitted in the same position.

Each drop contains information from all three search regions. There are three drops in total for that configuration, not three drops for each mode.

The code prints three candidate frequencies after each usable impact. A quality warning does not discard the recording or force you to restart the whole run.

### 6. Inspect the plots and results

The upper plot shows the recording. The green and red lines mark the part used for the FFT: **10-200 ms after the detected first impact**. Check that the later ball/base impact lies outside those lines. Cropping cannot remove another sound that overlaps the retained interval.

The lower plot shows the spectrum and selected candidates. The search regions are 90-170, 260-410 and 500-780 Hz. These are exploratory windows around the ideal bare-beam frequencies near 134, 368 and 722 Hz, with room for shifts from added mass. The attached clips and real supports change the system, so those bare-beam values are not exact predictions for a fitted configuration.

The strongest value in each window is a **candidate peak**, not a confirmed mode. Restricting the range can still select noise or another sound from the rig.

After the third drop, inspect:

```matlab
R.trialsHz
R.meanHz
R.stdHz
R.status
```

`trialsHz` has one row per drop and one column per search region. `meanHz` and `stdHz` show the three-drop means and sample standard deviations. A missing impact can leave `NaN` values in these results.

| Status | Meaning |
| --- | --- |
| `REVIEW_REQUIRED` | A signal check failed, or the measured scatter exceeds a completed repeatability limit. |
| `MODE_IDENTITIES_UNCONFIRMED` | Candidate signals passed the immediate checks, but their bending-mode identities have not been established. |
| `REPEATABILITY_LIMIT_NOT_SET` | Mode identities have been enabled, but a measured repeatability limit is still missing. |
| `CALIBRATION_INCOMPLETE` | The prerequisites for matching were reached, but the calibration table or matching tolerance is unfinished. |
| `CALIBRATION_OVERLAP` | The stored signatures are too close for the chosen matching tolerance. |
| `UNVALIDATED` | One table entry matched, but independent physical validation is still disabled. |
| `TABLE_MATCH` | A unique table match with validation enabled. This is an intended future state, not an achieved prototype result. |

For a measurement without the identification step, use `R = clip_student('measure');`. The `'spectrum'` option also makes three drops with the fitted configuration and returns `SPECTRUM_ONLY`, while retaining the signal-quality flags.

### 7. Keep the saved attempt

Both functions automatically save a timestamped `.mat` file in the Current Folder, including unsuccessful attempts. The printed `Saved:` path identifies the file. It contains a variable named `result`, with the raw recordings, background, timing, candidate frequencies and quality flags.

Keep these files for review rather than treating every printed number as a successful measurement. They are saved locally and are not uploaded by the code.

## Running the calibration trials

The calibration file takes the known position and total assembly mass. For example, to attempt the three candidate regions with the empty clip at 56 mm:

```matlab
C = clip_calibration_tests(56,1.30);
```

Complete the background recording and three prompted drops at 30 mm. Repeat for both assemblies at each of the five clip markings. That gives ten configurations and thirty impacts for a complete collection round.

Much of our development calibration tracked one higher-frequency feature instead. The same trial function can reproduce that measurement procedure with:

```matlab
C = clip_calibration_tests(56,1.30,[1400 1800]);
```

This produces one tracking frequency per drop, rather than a measurement of the three lower bending modes. It cannot fill the three-mode table.

The function prints and saves a `candidateCalibrationRow`. For a three-region attempt its order is:

| Position | Assembly mass | f1 mean | f2 mean | f3 mean | f1 scatter | f2 scatter | f3 scatter |
| --- | --- | --- | --- | --- | --- | --- | --- |
| mm | g | Hz | Hz | Hz | Hz | Hz | Hz |

`approvedCalibrationRow` stays `NaN` while the signal, repeatability or mode-confirmation requirements are unmet. The function does not automatically insert candidate values into the student's table.

## What we tried and where it stalled

We initially expected the first three bending modes to be clear enough to measure acoustically. For the ideal bare beam, our starting estimates were about 134, 368 and 722 Hz. In practice, the higher-frequency metallic ringing was much easier to capture.

We worked through several issues during development:

- **The later base impact contaminated a full-record spectrum.** We changed the analysis to retain only the early ringing after the first beam impact, while keeping the full recording so the timing could be checked.
- **Some recordings clipped.** We reduced microphone gain and changed the check to assess the ringing actually analysed. This avoids rejecting a useful segment solely because an excluded impact clipped. It does not repair distorted ringing.
- **Low-frequency peaks were mixed with background sound.** We compared equal-length background and impact segments and tried background-power subtraction during offline analysis. Subtraction did not reveal a dependable set of three modes. The submitted code compares the peak with the background; it does not perform that offline subtraction.
- **A quieter room did not resolve the problem.** We recorded the bare beam again at home and also compared phone recordings. Higher-frequency features remained clearer, so we could not establish that the laptop microphone alone was responsible.
- **Narrower frequency searches still gave uncertain candidates.** We inspected all thirty configuration recordings around the theoretical lower-mode regions. Some features recurred, but no combination supplied a defensible set of all three bending modes. Several apparent second-mode-region peaks were also present in the saved background.
- **One-peak calibration had its own ambiguity.** Several configurations produced almost the same tracking frequency. Others gave inconsistent maxima or a weak drop. A small scatter within one set did not prove that an unknown clip could be identified reliably.

We considered changing the supports to investigate their effect, but did not carry out the proposed suspension test because we had to retain the existing setup. Support effects, weak sound radiation and the recording chain therefore remain possible explanations, rather than confirmed causes.

### Single-peak results from the development recordings

These values concern the feature selected in the **1,400-1,800 Hz band**. They are not the first three bending-mode frequencies and do not populate the blank three-mode table.

| Clip position | Assembly mass | Tracking mean (Hz) | Sample scatter (Hz) | Finding |
| --- | --- | --- | --- | --- |
| 56 mm | 1.30 g | 1696.71 | 0.66 | Consistent within the set; overlaps other light-clip cases |
| 56 mm | 3.05 g | 1705.48 | 8.04 | Inconsistent selection; one weak drop |
| 112 mm | 1.30 g | 1707.68 | 0.38 | Consistent initial development feature |
| 112 mm | 3.05 g | 1727.63 | 1.14 | Consistent development feature; a repeat set gave the same centre |
| 140 mm | 1.30 g | 1660.75 | 0.76 | Consistent initial development feature |
| 140 mm | 3.05 g | 1497.59 | 1.37 | Consistent initial development feature |
| 168 mm | 1.30 g | 1694.30 | 1.00 | Consistent within the set; overlaps light/56 and light/224 |
| 168 mm | 3.05 g | No accepted centre | Not reported | Reconstructed first-impact analysis selected inconsistent peaks |
| 224 mm | 1.30 g | 1696.93 | 0.38 | Consistent within the set; overlaps light/56 and light/168 |
| 224 mm | 3.05 g | 1634.43 | 1.37 | Consistent frequency; one drop narrowly failed the strength check |

Older recordings did not all retain the separate background or original analysis interval. Some of their values required reconstructing the onset, so they do not have the same quality evidence as the newer files. These are development measurements, not independently validated identification results. Raw experimental recordings are not included in this repository.

## The gaps left in the code

The student's embedded table has ten rows, with position and mass filled in. Its three frequency means and three standard deviations remain `NaN`. `maxStdHz` and `matchLimitHz` are also `NaN`, while `modeBandsConfirmed` and `validated` remain `false`.

Those settings represent experimental work we did not complete. The original repeatability design target was 0.15 Hz, but it was not demonstrated. The current 190 ms interval has about 5.26 Hz native Fourier spacing. Zero padding produces a finer display grid; it does not establish the required measurement precision.

To finish the intended activity, we would need to confirm and track the same three modes, collect repeated calibration data, show that the allowed configurations are distinguishable, choose tolerances from real trials and run independent blind tests. Only then should the corresponding gaps and validation flags be completed. One-peak results and theoretical predictions must not be inserted as missing three-mode calibration data.

## What this submission demonstrates

The intended activity remains identifying a hidden clip from its effect on the first three bending modes. The prototype demonstrates the apparatus, repeated recording procedure, first-impact analysis and an investigation of why the identification stage was not achieved.

Within the available development and testing time, we could not reliably resolve those modes or establish identification accuracy. Improved sensing and further support testing are sensible next investigations. We have not shown that buying an external microphone would, by itself, solve the problem.

The final files retain the unfinished work openly. Their acquisition and analysis sections are identical. Numerical checks covered clean synthetic peaks, silence, analysed clipping, later-impact exclusion and matching logic. The final cleaned-up MATLAB files were not executed in MATLAB or Octave in the preparation environment, and those checks do not validate the physical prototype.
