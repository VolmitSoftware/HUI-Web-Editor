(function () {
  'use strict';

  function installTooltipOverlay() {
  var overlayId = 'gloss-tooltip-overlay';
  var contentId = 'gloss-tooltip-overlay-content';
  var activeTrigger = null;
  var describedElement = null;
  var previousDescription = null;
  var touchHideTimer = 0;
  var positionFrame = 0;

  var overlay = document.createElement('div');
  overlay.id = overlayId;
  overlay.className = 'gloss-tooltip-overlay';
  overlay.setAttribute('aria-hidden', 'true');

  var content = document.createElement('div');
  content.id = contentId;
  content.className = 'gloss-tooltip-overlay-content';
  content.setAttribute('role', 'tooltip');
  overlay.appendChild(content);

  function ensureOverlay() {
    if (!overlay.isConnected && document.body) {
      document.body.appendChild(overlay);
    }
    document.documentElement.classList.add('gloss-tooltip-overlay-ready');
  }

  ensureOverlay();

  function prepareTitle(element) {
    if (!(element instanceof Element) || element.hasAttribute('data-no-tooltip')) {
      return;
    }
    var title = element.getAttribute('title');
    if (!title || !title.trim()) {
      return;
    }
    element.dataset.glossTooltipText = title;
    element.removeAttribute('title');
  }

  function prepareTitles(root) {
    if (!(root instanceof Element)) {
      return;
    }
    if (root.hasAttribute('title')) {
      prepareTitle(root);
    }
    root.querySelectorAll('[title]').forEach(prepareTitle);
  }

  function findTrigger(target) {
    if (!(target instanceof Element) || target.closest('#' + overlayId)) {
      return null;
    }
    var frameworkTrigger = target.closest(
      '.arcane-css-tooltip-trigger, .arcane-tooltip-trigger'
    );
    if (frameworkTrigger) {
      return frameworkTrigger;
    }
    var nativeTrigger = target.closest('[data-gloss-tooltip-text]');
    if (nativeTrigger) {
      return nativeTrigger;
    }
    var floatingTrigger = target.closest(
      '.arcane-floating-container, .neon-floating-container'
    );
    return floatingTrigger && hovercardFor(floatingTrigger) ? floatingTrigger : null;
  }

  function hovercardFor(trigger) {
    if (!trigger.matches('.arcane-floating-container, .neon-floating-container')) {
      return null;
    }
    return trigger.querySelector('[data-arcane-surface="hovercard"]');
  }

  function tooltipText(trigger) {
    if (trigger.matches('.arcane-css-tooltip-trigger, .arcane-tooltip-trigger')) {
      var dataText = trigger.dataset.tooltip;
      if (dataText && dataText.trim()) {
        return dataText;
      }
      var source = trigger.querySelector(
        ':scope > .arcane-css-tooltip-content, :scope > .arcane-tooltip'
      );
      if (source && source.textContent && source.textContent.trim()) {
        return source.textContent.trim();
      }
    }
    var nativeText = trigger.dataset.glossTooltipText;
    return nativeText && nativeText.trim() ? nativeText : '';
  }

  function appendRichContent(source) {
    var wrapper = document.createElement('div');
    wrapper.className = 'gloss-tooltip-overlay-rich';
    source.childNodes.forEach(function (node) {
      if (node instanceof Element && /arrow/i.test(node.className || '')) {
        return;
      }
      var clone = node.cloneNode(true);
      if (clone instanceof Element) {
        clone.removeAttribute('id');
        clone.querySelectorAll('[id]').forEach(function (element) {
          element.removeAttribute('id');
        });
      }
      wrapper.appendChild(clone);
    });
    content.replaceChildren(wrapper);
  }

  function renderContent(trigger) {
    var hovercard = hovercardFor(trigger);
    if (hovercard && hovercard.textContent && hovercard.textContent.trim()) {
      appendRichContent(hovercard);
      return true;
    }
    var text = tooltipText(trigger);
    if (!text) {
      return false;
    }
    content.textContent = text;
    return true;
  }

  function preferredSide(trigger) {
    var source = hovercardFor(trigger);
    var placement = trigger.dataset.tooltipPosition ||
      (source && source.dataset.arcaneAnchorPlacement) || 'top';
    var normalized = placement.toLowerCase();
    if (normalized.indexOf('bottom') === 0) return 'bottom';
    if (normalized.indexOf('left') === 0) return 'left';
    if (normalized.indexOf('right') === 0) return 'right';
    return 'top';
  }

  function candidateFor(side, triggerRect, tooltipRect, gap) {
    if (side === 'bottom') {
      return {
        side: side,
        x: triggerRect.left + (triggerRect.width - tooltipRect.width) / 2,
        y: triggerRect.bottom + gap
      };
    }
    if (side === 'left') {
      return {
        side: side,
        x: triggerRect.left - tooltipRect.width - gap,
        y: triggerRect.top + (triggerRect.height - tooltipRect.height) / 2
      };
    }
    if (side === 'right') {
      return {
        side: side,
        x: triggerRect.right + gap,
        y: triggerRect.top + (triggerRect.height - tooltipRect.height) / 2
      };
    }
    return {
      side: 'top',
      x: triggerRect.left + (triggerRect.width - tooltipRect.width) / 2,
      y: triggerRect.top - tooltipRect.height - gap
    };
  }

  function oppositeSide(side) {
    if (side === 'top') return 'bottom';
    if (side === 'bottom') return 'top';
    if (side === 'left') return 'right';
    return 'left';
  }

  function fits(candidate, tooltipRect, viewportWidth, viewportHeight, padding) {
    return candidate.x >= padding &&
      candidate.y >= padding &&
      candidate.x + tooltipRect.width <= viewportWidth - padding &&
      candidate.y + tooltipRect.height <= viewportHeight - padding;
  }

  function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(value, Math.max(minimum, maximum)));
  }

  function positionTooltip() {
    positionFrame = 0;
    if (!activeTrigger || !activeTrigger.isConnected) {
      hideTooltip();
      return;
    }
    var visualViewport = window.visualViewport;
    var viewportWidth = visualViewport ? visualViewport.width :
      document.documentElement.clientWidth;
    var viewportHeight = visualViewport ? visualViewport.height :
      document.documentElement.clientHeight;
    var padding = 8;
    var gap = 8;
    content.style.maxWidth = Math.max(
      1,
      Math.min(320, viewportWidth - padding * 2)
    ) + 'px';
    content.style.maxHeight = Math.max(1, viewportHeight - padding * 2) + 'px';
    var triggerRect = activeTrigger.getBoundingClientRect();
    var tooltipRect = content.getBoundingClientRect();
    var preferred = preferredSide(activeTrigger);
    var sides = [preferred, oppositeSide(preferred), 'top', 'bottom', 'left', 'right'];
    var candidate = candidateFor(preferred, triggerRect, tooltipRect, gap);
    for (var index = 0; index < sides.length; index += 1) {
      var next = candidateFor(sides[index], triggerRect, tooltipRect, gap);
      if (fits(next, tooltipRect, viewportWidth, viewportHeight, padding)) {
        candidate = next;
        break;
      }
    }
    var x = clamp(
      candidate.x,
      padding,
      viewportWidth - tooltipRect.width - padding
    );
    var y = clamp(
      candidate.y,
      padding,
      viewportHeight - tooltipRect.height - padding
    );
    content.style.left = Math.round(x) + 'px';
    content.style.top = Math.round(y) + 'px';
    content.dataset.side = candidate.side;
  }

  function requestPosition() {
    if (positionFrame || !activeTrigger) {
      return;
    }
    positionFrame = window.requestAnimationFrame(positionTooltip);
  }

  function restoreDescription() {
    if (!describedElement) {
      return;
    }
    if (previousDescription === null) {
      describedElement.removeAttribute('aria-describedby');
    } else {
      describedElement.setAttribute('aria-describedby', previousDescription);
    }
    describedElement = null;
    previousDescription = null;
  }

  function describe(element) {
    restoreDescription();
    describedElement = element;
    previousDescription = element.getAttribute('aria-describedby');
    var descriptions = previousDescription ? previousDescription.split(/\s+/) : [];
    if (descriptions.indexOf(contentId) === -1) {
      descriptions.push(contentId);
    }
    element.setAttribute('aria-describedby', descriptions.join(' ').trim());
  }

  function showTooltip(trigger, descriptionTarget) {
    window.clearTimeout(touchHideTimer);
    if (activeTrigger !== trigger) {
      content.classList.remove('is-visible');
    }
    activeTrigger = trigger;
    if (!renderContent(trigger)) {
      hideTooltip();
      return;
    }
    describe(descriptionTarget || trigger);
    overlay.setAttribute('aria-hidden', 'false');
    content.style.left = '0px';
    content.style.top = '0px';
    positionTooltip();
    content.classList.add('is-visible');
  }

  function hideTooltip() {
    window.clearTimeout(touchHideTimer);
    if (positionFrame) {
      window.cancelAnimationFrame(positionFrame);
      positionFrame = 0;
    }
    activeTrigger = null;
    content.classList.remove('is-visible');
    overlay.setAttribute('aria-hidden', 'true');
    restoreDescription();
  }

  function onMouseOver(event) {
    var trigger = findTrigger(event.target);
    if (!trigger || trigger === activeTrigger) {
      return;
    }
    showTooltip(trigger, event.target);
  }

  function onMouseOut(event) {
    if (!activeTrigger) {
      return;
    }
    var related = event.relatedTarget;
    if (related instanceof Node && activeTrigger.contains(related)) {
      return;
    }
    if (activeTrigger.matches(':focus-within')) {
      return;
    }
    hideTooltip();
  }

  function onFocusIn(event) {
    var trigger = findTrigger(event.target);
    if (trigger) {
      showTooltip(trigger, event.target);
    }
  }

  function onFocusOut(event) {
    if (!activeTrigger) {
      return;
    }
    var related = event.relatedTarget;
    if (related instanceof Node && activeTrigger.contains(related)) {
      return;
    }
    if (activeTrigger.matches(':hover')) {
      return;
    }
    hideTooltip();
  }

  function onPointerDown(event) {
    if (event.pointerType !== 'touch') {
      return;
    }
    var trigger = findTrigger(event.target);
    if (!trigger) {
      hideTooltip();
      return;
    }
    showTooltip(trigger, event.target);
    touchHideTimer = window.setTimeout(hideTooltip, 2400);
  }

  function onKeyDown(event) {
    if (event.key === 'Escape') {
      hideTooltip();
    }
  }

  prepareTitles(document.documentElement);
  new MutationObserver(function (records) {
    ensureOverlay();
    records.forEach(function (record) {
      if (record.type === 'attributes') {
        prepareTitle(record.target);
      } else {
        record.addedNodes.forEach(prepareTitles);
      }
    });
    if (activeTrigger && !activeTrigger.isConnected) {
      hideTooltip();
    }
  }).observe(document.body, {
    attributes: true,
    attributeFilter: ['title'],
    childList: true,
    subtree: true
  });

  document.addEventListener('mouseover', onMouseOver, true);
  document.addEventListener('mouseout', onMouseOut, true);
  document.addEventListener('focusin', onFocusIn, true);
  document.addEventListener('focusout', onFocusOut, true);
  document.addEventListener('pointerdown', onPointerDown, true);
  document.addEventListener('keydown', onKeyDown, true);
  window.addEventListener('resize', requestPosition, {passive: true});
  window.addEventListener('scroll', requestPosition, {passive: true, capture: true});
  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', requestPosition, {passive: true});
    window.visualViewport.addEventListener('scroll', requestPosition, {passive: true});
  }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', installTooltipOverlay, {once: true});
  } else {
    installTooltipOverlay();
  }
})();
