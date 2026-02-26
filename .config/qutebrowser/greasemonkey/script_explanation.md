# Greasemonkeyスクリプト解説: YouTube Ad Helper

## 概要

このGreasemonkeyスクリプトは、YouTubeの広告再生を快適にするための補助ツールです。広告を自動でスキップするのではなく、ユーザーが手動で簡単にスキップできるように、完璧な下準備を整えることに特化しています。

qutebrowserのようなキーボード中心のブラウザでの使用に最適化されています。

## 主な機能

このスクリプトは、Webページを300ミリ秒ごとに監視し、以下の動作を自動的に実行します。

1.  **広告の検出**: YouTubeの広告が再生されていることを検出します。
2.  **ミュート & 高速再生**: 広告が始まると、即座に動画をミュート（消音）し、再生速度を16倍速に引き上げます。これにより、広告の待ち時間を大幅に短縮します。
3.  **スキップ準備**:
    *   広告に「スキップボタン」が表示されると、スクリプトはそれを即座に検出します。
    *   検出と同時に、動画を**一時停止**します。
    *   さらに、スキップボタンに**キーボードのフォーカスを自動で当て続けます**。

## 使用方法

このスクリプトが有効になっていると、YouTubeで広告が始まった際に自動で高速再生が始まります。

スキップ可能な広告の場合、画面にスキップボタンが表示された瞬間に**動画が一時停止し、ボタンがハイライトされます**。ユーザーは**ご自身のタイミングで `Enter` キーを押すだけ**で、広告をスキップできます。

## スクリプト全文

```javascript
// ==UserScript==
// @name         YouTube Ad Helper (Stateful Pause)
// @namespace    http://tampermonkey.net/
// @version      4.1
// @description  Checks if the video is actually playing before pausing to prevent toggling.
// @author       Gemini
// @match        *://*.youtube.com/*
// @grant        none
// ==/UserScript==

(function() {
    'use strict';

    const LOG_PREFIX = '[YT Ad Helper]';
    let isAdPlaying = false;

    const setupManualSkip = (video) => {
        const potentialButtons = document.querySelectorAll(
            "[id^='skip-button:'], "
            + ".ytp-skip-ad-button, "
            + ".ytp-ad-skip-button, "
            + ".ytp-ad-skip-button-modern"
        );

        for (const button of potentialButtons) {
            if (button.offsetParent !== null) {
                // 1. Persistently apply focus to the skip button.
                button.focus();

                // 2. Check the video's actual state. Only click pause if it's currently playing.
                if (!video.paused) {
                    const playPauseButton = document.querySelector('.ytp-play-button');
                    if (playPauseButton) {
                        console.log(LOG_PREFIX, 'Skip button visible and video is playing. Pausing now.');
                        playPauseButton.click();
                    }
                }
                return; // A button is visible, job done for this interval.
            }
        }
    };

    setInterval(() => {
        const video = document.querySelector('video');
        if (!video) return;

        const adModule = document.querySelector('.ytp-ad-module, .video-ads');
        const adShowing = document.querySelector('.ad-showing');

        if (adModule && adShowing) {
            if (!isAdPlaying) {
                isAdPlaying = true;
            }
            video.muted = true;
            video.playbackRate = 16;

            // Pass the video element to the function.
            setupManualSkip(video);

        } else {
            // When the ad is over, restore everything.
            if (isAdPlaying) {
                if (video.muted) video.muted = false;
                if (video.playbackRate !== 1) video.playbackRate = 1;
                isAdPlaying = false;
            }
        }
    }, 300);
})();
```
