// Run with: node scripts/tests/test_org_zettel_render.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const template = fs.readFileSync(path.join(__dirname, '../org-zettel.html'), 'utf8');
const renderer = vm.createContext({ URL, URLSearchParams });
for (const [start, end] of [
  ['  function escHtml(', '  // Strip org markup'],
  ['  function youtubeVideo(', '  // Pin management'],
  ['  function inlineMarkup(', '  // Path resolution'],
]) {
  const offset = template.indexOf(start);
  assert.ok(offset >= 0 && template.indexOf(end, offset) > offset);
  vm.runInContext(template.slice(offset, template.indexOf(end, offset)), renderer);
}

const id = 'abc_def-123';
const thumbnail = `https://img.youtube.com/vi/${id}/hqdefault.jpg`;

test('the complete viewer script parses', () => {
  new vm.Script(template.match(/<script>([\s\S]*?)<\/script>/)[1]);
});

test('Org links and pasted URLs embed in articles and produce thumbnails for cards', () => {
  for (const url of [
    `https://www.youtube.com/watch?v=${id}`,
    `https://youtube.com/watch?feature=share&v=${id}`,
    `https://youtu.be/${id}?si=shared`,
    `https://m.youtube.com/watch?v=${id}`,
    `https://www.youtube.com/shorts/${id}`,
    `https://www.youtube.com/live/${id}`,
    `https://www.youtube.com/embed/${id}`,
  ]) {
    for (const note of [url, `[[${url}]]`, `[[${url}][動画]]`]) {
      const html = renderer.renderOrg(note);
      assert.equal((html.match(/<iframe /g) || []).length, 1, note);
      assert.ok(html.includes(`src="https://www.youtube.com/embed/${id}"`), note);
      assert.ok(html.includes('allowfullscreen'));
      assert.ok(!html.includes('<img'));
      assert.equal(renderer.extractThumbnail(note), thumbnail, note);
      assert.ok(!html.includes('\x01'));
    }
  }
});

test('start times survive conversion and links remain safely escaped', () => {
  for (const suffix of ['?t=90', '?t=1m30s', '?start=90', '#t=90']) {
    assert.ok(renderer.inlineMarkup(`https://youtu.be/${id}${suffix}`)
      .includes(`/embed/${id}?start=90"`));
  }
  const html = renderer.inlineMarkup(`[[https://youtube.com/watch?v=${id}&t=30][A & B <test> "title"]]`);
  assert.ok(html.includes('A &amp; B &lt;test&gt; &quot;title&quot;'));
  assert.ok(html.includes(`href="https://youtube.com/watch?v=${id}&amp;t=30"`));
  assert.ok(renderer.inlineMarkup(`Watch (https://youtu.be/${id}).`).endsWith('</a>).'));
});

test('ordinary links, images and source code retain their rendering', () => {
  for (const url of [
    `https://youtube.com.example.com/watch?v=${id}`,
    `https://example.com/watch?v=${id}`,
    `https://youtu.be/${id}x`,
    'https://youtube.com/playlist?list=example',
  ]) {
    assert.ok(!renderer.inlineMarkup(`[[${url}][Link]]`).includes('<iframe'));
    assert.equal(renderer.extractThumbnail(url), null);
  }
  assert.ok(renderer.inlineMarkup('[[file:Note.org][Note]]').includes('data-target="Note.org"'));
  assert.ok(renderer.inlineMarkup('[[file:photo.png]]').includes('<img'));
  assert.ok(renderer.inlineMarkup('[[https://example.com/photo.jpg]]').includes('<img'));
  assert.ok(renderer.inlineMarkup('*bold*').includes('<strong>bold</strong>'));
  assert.ok(!renderer.renderOrg(`#+begin_src text\nhttps://youtu.be/${id}\n#+end_src`).includes('<iframe'));
});
