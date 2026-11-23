//
//  CardWebViewConfig.swift
//  ReviewFeature
//
//  Created by Vladimir Gusev on 01.05.2026.
//

import Foundation
import WebKit

enum CardWebViewReplayMode: String, Sendable {
    case question
    case answerOnly
    case answerWithQuestion
}

package enum CardWebViewContentAlignment: String, Sendable {
    case top
    case center
}

extension CardWebView {
    // Card templates run in the page world and cannot call the grading bridge.
    static let reviewTapWorld = WKContentWorld.world(name: "AmgiReviewTap")

    static let reviewTapScript = """
    (() => {
        const controls = [
            'a, button, input, textarea, select, option, label, summary, [contenteditable], [onclick]',
            'audio, video, canvas, iframe, object, embed',
            '.replay-button, .replay-btn, .sound-btn, #image-occlusion-container',
            '[role="button"], [role="link"], [role="checkbox"], [role="tab"], [role="switch"]'
        ].join(', ');
        const isControl = event => event.composedPath().some(node =>
            node instanceof Element && node.matches(controls)
        );
        const token = () => document.getElementById('qa')?.dataset.amgiReviewTap;
        let start = null;

        window.addEventListener('pointerdown', event => {
            const cardToken = token();
            start = event.isTrusted && event.isPrimary && event.button === 0 && cardToken && !isControl(event)
                ? { cardToken, x: event.clientX, y: event.clientY, time: performance.now() }
                : null;
        }, true);
        window.addEventListener('pointercancel', () => { start = null; }, true);
        window.addEventListener('contextmenu', () => { start = null; }, true);

        window.addEventListener('click', event => {
            if (!event.isTrusted) return;
            const tap = start;
            start = null;
            if (!tap || tap.cardToken !== token() || event.defaultPrevented || isControl(event)) return;
            if (event.detail === 0 || window.getSelection()?.isCollapsed === false) return;
            if (performance.now() - tap.time > 500) return;
            if (Math.hypot(event.clientX - tap.x, event.clientY - tap.y) > 10) return;

            const fraction = event.clientX / window.innerWidth;
            if (fraction >= 0 && fraction < 1) {
                window.webkit.messageHandlers.amgiReviewTap.postMessage({ token: tap.cardToken, fraction });
            }
        });
    })();
    """
}
