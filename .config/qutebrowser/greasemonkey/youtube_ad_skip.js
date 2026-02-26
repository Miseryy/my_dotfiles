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
