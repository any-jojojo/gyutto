(() => {
  const template = document.getElementById('email-template');
  const status = document.querySelector('.copy-status');
  const buttons = document.querySelectorAll('[data-copy-template]');
  if (!template || !status) return;

  function copyWithSelection(text) {
    const field = document.createElement('textarea');
    field.value = text;
    field.readOnly = true;
    field.style.cssText = 'position:fixed;top:0;left:0;opacity:0;font-size:16px;';
    const previousFocus = document.activeElement;
    document.body.appendChild(field);
    try {
      field.focus({ preventScroll: true });
      field.select();
      field.setSelectionRange(0, text.length);
      return document.execCommand('copy');
    } finally {
      field.remove();
      previousFocus?.focus({ preventScroll: true });
    }
  }

  for (const button of buttons) {
    button.addEventListener('click', async () => {
      status.textContent = '';
      const text = template.textContent;
      let copied = false;
      try {
        if (navigator.clipboard?.writeText) {
          await navigator.clipboard.writeText(text);
          copied = true;
        }
      } catch (_) { /* Try selection copying when clipboard access is denied. */ }
      if (!copied) {
        try { copied = copyWithSelection(text); } catch (_) { /* Show manual copy instructions. */ }
      }
      status.textContent = copied
        ? 'メール本文をコピーしました。メールに貼り付けて［ ］内を書き換えてください。'
        : 'コピーできませんでした。例文を開き、本文を選択してコピーしてください。';
    });
  }
})();
