/**
 * Intercept cross-frame data payloads emitted from your local/production Flutter instances
 */
window.addEventListener("message", (platformEvent) => {
    if (platformEvent.data && typeof platformEvent.data === "string") {
        try {
            const parsedMessageData = JSON.parse(platformEvent.data);
            if (parsedMessageData.source === "AUTONILAM_FLUTTER_WEB") {
                // Drop payload securely into extension local memory cache structures
                chrome.storage.local.set({ cachedNilamPayload: parsedMessageData.payload }, () => {
                    // Immediately send parent directly onto the official book recording view tab
                    window.open("https://ains.moe.gov.my/student/records/add", "_blank");
                });
            }
        } catch (parseFailureAnomaly) {
            // Absorb unrelated system stream string notifications safely
        }
    }
});

/**
 * Perform Native Form Input field injection if the active tab matches the target endpoint layout
 */
if (window.location.href.includes("ains.moe.gov.my/student/records/add")) {
    chrome.storage.local.get(["cachedNilamPayload"], (extensionCacheStorage) => {
        if (extensionCacheStorage.cachedNilamPayload) {
            const dataset = extensionCacheStorage.cachedNilamPayload;

            /**
             * Bypasses client form framework deadlocks (Angular/React state retention systems)
             */
            const injectTextIntoFormNode = (cssSelectorString, entryValueString) => {
                const structuralInputNode = document.querySelector(cssSelectorString);
                if (!structuralInputNode) return;

                structuralInputNode.value = entryValueString;

                // Force frameworks to evaluate changes accurately via sequence validation bubbling
                structuralInputNode.dispatchEvent(new Event('input', { bubbles: true }));
                structuralInputNode.dispatchEvent(new Event('change', { bubbles: true }));
            };

            // Execute injection sequences after a small delay to allow DOM mounting
            setTimeout(() => {
                // Map elements to target AINS CSS Selector paths (Update selectors if MoE alters DOM layout structures)
                injectTextIntoFormNode("input[formcontrolname='title']", dataset.title);
                injectTextIntoFormNode("input[formcontrolname='author']", dataset.author);
                injectTextIntoFormNode("input[formcontrolname='publisher']", dataset.publisher);
                injectTextIntoFormNode("textarea[formcontrolname='synopsis']", dataset.ulasan);

                // Process radio buttons for book type categorization selection routines
                const targetRadioSelector = dataset.isFiction
                    ? "input[type='radio'][value='fiksyen']"
                    : "input[type='radio'][value='bukan_fiksyen']";

                const targetRadioDomNode = document.querySelector(targetRadioSelector);
                if (targetRadioDomNode) {
                    targetRadioDomNode.click();
                    targetRadioDomNode.dispatchEvent(new Event('change', { bubbles: true }));
                }

                // Wipe data cache buffer clean to prevent injection loops on next execution cycles
                chrome.storage.local.remove(["cachedNilamPayload"]);
            }, 2500);
        }
    });
}