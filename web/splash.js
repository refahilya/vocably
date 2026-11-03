// Removes the navy splash once Flutter paints its first frame. Kept in its
// own file (not inline) so the Content-Security-Policy in firebase.json can
// allow scripts from 'self' only, without a per-script hash.
window.addEventListener('flutter-first-frame', function () {
  var splash = document.getElementById('app-splash');
  if (splash) splash.remove();
  document.documentElement.style.background = '#F2F4FA';
  document.body.style.background = '#F2F4FA';
});
