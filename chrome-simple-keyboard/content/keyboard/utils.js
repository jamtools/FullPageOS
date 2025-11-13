
export function triggerFormSubmit(el) {
    const form = el?.form;

    if (form) {
        // Preferred: triggers real submit event
        if (typeof form.requestSubmit === 'function') {
            form.requestSubmit();
        } else {
            // Fallback for older browsers (use a fake submit button)
            const tempBtn = document.createElement('button');
            tempBtn.type = 'submit';
            tempBtn.style.display = 'none';
            form.appendChild(tempBtn);
            tempBtn.click();
            form.removeChild(tempBtn);
        }
    }
}

export function triggerElementAction(el) {
    if (typeof el.click === 'function') {
        el.click();
    }
}

export function isVisible(el) {
    const style = window.getComputedStyle(el);
    return (
        !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length) &&
        style.visibility !== 'hidden' &&
        style.display !== 'none' &&
        parseFloat(style.opacity) > 0
    );
}

export function isChildElement(child, target) {
    if(target === child) {
        return true
    }
    if(!!child.parentElement) {
        return isChildElement(child.parentElement, target)
    }
    return false
}

export function performNativeKeyPress(element, keyCode) {
    element.dispatchEvent(new Event("keydown", { keyCode: keyCode, which: keyCode }));
    element.dispatchEvent(new Event("keypress", { keyCode: keyCode, which: keyCode }));
    element.dispatchEvent(new Event("input", { bubbles: true }));
    //element.dispatchEvent(new Event("change", { bubbles: true }));
}

/**
 * Check if an element is a text input (including contenteditable)
 */
export function isTextInput(el) {
    if (!el || el.nodeType !== 1) {
        return false;
    }

    const tagName = el.tagName?.toLowerCase();

    // Check standard input/textarea elements
    if (tagName === 'input' || tagName === 'textarea') {
        // Exclude non-text input types
        const type = el.type?.toLowerCase();
        if (tagName === 'input' && ['checkbox', 'radio', 'button', 'color', 'image', 'file', 'hidden', 'submit', 'reset'].includes(type)) {
            return false;
        }
        // Exclude readonly fields
        if (el.hasAttribute('readonly')) {
            return false;
        }
        return true;
    }

    // Check contenteditable
    if (el.isContentEditable || el.getAttribute('contenteditable') === 'true') {
        return true;
    }

    // Check ARIA textbox role
    if (el.getAttribute('role') === 'textbox') {
        return true;
    }

    return false;
}

/**
 * Find the first text input in an event's composed path (works across shadow DOM)
 */
export function findTextInputInPath(event) {
    // Use composedPath to traverse shadow DOM boundaries
    const path = event.composedPath ? event.composedPath() : [event.target];

    for (const node of path) {
        if (isTextInput(node)) {
            return node;
        }
    }

    return null;
}

/**
 * Deep search for active element, traversing shadow DOM
 */
export function getDeepActiveElement(startElement = document) {
    let activeEl = startElement.activeElement;

    // Traverse shadow DOM trees
    while (activeEl && activeEl.shadowRoot && activeEl.shadowRoot.activeElement) {
        activeEl = activeEl.shadowRoot.activeElement;
    }

    return activeEl;
}