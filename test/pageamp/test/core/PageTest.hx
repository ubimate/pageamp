package pageamp.test.core;

import pageamp.util.PropertyTool;
import pageamp.core.Element;
import pageamp.core.Page;
import haxe.unit.TestCase;

using pageamp.web.DomTools;
using pageamp.util.PropertyTool;

@:access(pageamp.core.Element)
class PageTest extends TestCase {

	function testPage1() {
		var page = new Page(TestAll.getDoc());
		assertEquals('<html><head></head>'
		+ '<body></body></html>', page.doc.domToString());
	}

	function testPage2() {
		var props = PropertyTool.set(null, Page.PAGE_LANG, 'en');
		props.set(Element.ATTRIBUTE_PREFIX + 'class', 'app');
		var p = new Page(TestAll.getDoc(), props);
		assertEquals('<html lang="en"><head></head>'
		+ '<body class="app"></body></html>', p.doc.domToString());
		p.set(Page.PAGE_LANG, 'es');
		assertEquals('<html lang="es"><head></head>'
		+ '<body class="app"></body></html>', p.doc.domToString());
		p.set(Element.ATTRIBUTE_PREFIX + 'class', 'demo');
		assertEquals('<html lang="es"><head></head>'
		+ '<body class="demo"></body></html>', p.doc.domToString());
		p.set(Page.PAGE_LANG, null);
		assertEquals('<html><head></head>'
		+ '<body class="demo"></body></html>', p.doc.domToString());
	}

	function testPage3() {
		var p = new Page(TestAll.getDoc());
		assertEquals('<html><head></head>'
		+ '<body></body></html>', p.doc.domToString());
		p.set(Page.PAGE_LANG, 'es');
		assertEquals('<html lang="es"><head></head>'
		+ '<body></body></html>', p.doc.domToString());
		p.set(Element.ATTRIBUTE_PREFIX + 'class', 'demo');
		assertEquals('<html lang="es"><head></head>'
		+ '<body class="demo"></body></html>', p.doc.domToString());
	}

	function testPage4() {
		var p = new Page(TestAll.getDoc(), null, function(p:Page) {
			new Element(p, {innerText:'foo'});
		});
		assertEquals('<html><head></head>'
		+ '<body><div>foo</div></body></html>', p.doc.domToString());
	}

	function testPage5() {
		var p = new Page(TestAll.getDoc(), {v:'bar'}, function(p:Page) {
			new Element(p, {innerText:"v: ${v}"});
		});
		assertEquals('<html><head></head>'
		+ '<body><div>v: bar</div></body></html>', p.doc.domToString());
	}

	function testPageHead() {
		var p = new Page(TestAll.getDoc());
		assertTrue(p.head != null);
		assertEquals(p.head.dom, p.getDocument().domGetHead());
		assertEquals(p.get('head'), p.head.scope);
	}

}
