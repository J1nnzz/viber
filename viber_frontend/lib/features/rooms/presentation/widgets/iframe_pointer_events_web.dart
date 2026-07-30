// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void setIframePointerEvents({required bool enable}) {
  final value = enable ? 'auto' : 'none';
  js.context.callMethod('eval', [
    '''
    (function() {
      var iframes = document.querySelectorAll('iframe');
      for (var i = 0; i < iframes.length; i++) {
        iframes[i].style.pointerEvents = '$value';
      }
    })();
    '''
  ]);
}
