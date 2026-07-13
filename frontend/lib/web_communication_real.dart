import 'dart:html' as native_browser_html;

void dispatchMessageToWindow(String messagePayload) {
  // Transmits execution data objects clean through cross-frame Javascript listeners
  native_browser_html.window.postMessage(messagePayload, '*');
}
