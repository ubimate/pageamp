package pageamp.test2;

import pageamp.test2.react.ValueTest;
import pageamp.test2.core.NodeTest;
import pageamp.test2.core.ElementTest;
import pageamp.test2.react.ScopeTest;
import pageamp.web.DomTools.DomDocument;
import haxe.unit.TestRunner;
#if js
	import js.Browser;
#elseif php
	import php.Lib;
	import php.Web;
	import htmlparser.HtmlDocument;
#end

class TestAll {
	static var doc: DomDocument;

	public static function main() {
		new Runner(function(r:Runner) {
			doc = r.doc;
			// react
			r.add(new ScopeTest());
			r.add(new ValueTest());
			// core
			r.add(new NodeTest());
			r.add(new ElementTest());
			r.run();
		});
	}

	public static function getDoc(): DomDocument {
#if js
		doc.documentElement.innerHTML = '<html><head></head><body></body></html>';
		return doc;
#elseif php
		return new HtmlDocument('<html><head></head><body></body></html>');
#end
	}

}

class Runner extends TestRunner {
	public var doc: DomDocument;

	public function new(cb:Runner->Void) {
		super();
#if js
		// style
		var style = Browser.document.createStyleElement();
		style.innerHTML = 'body {color:#ccc;background:#222;}';
		Browser.document.head.appendChild(style);

		// create #haxe:trace div
		var iframe = Browser.document.createIFrameElement();
		iframe.onload = function(_) {
			doc = iframe.contentDocument;

			// customize TestRunner.print()
			var div = js.Browser.document.getElementById("haxe:trace");
			TestRunner.print = function(v:Dynamic) {
				if (div != null) {
					var s = StringTools.htmlEscape(v+'').split("\n").join("<br/>");
					div.innerHTML += s;
				} else {
					untyped __js__("console").log(v+'');
				}
			}
			cb(this);
		}
		iframe.style.opacity = '0';
		Browser.document.body.appendChild(iframe);

#elseif php
		Lib.println('<html><head><style>body {color:#ccc;background:#222;}'
		+'</style></head><body><pre>');

		// customize TestRunner.print()
		TestRunner.print = function(v:Dynamic) {
			Lib.print(StringTools.htmlEscape(v+''));
		}

		cb(this);
#end
	}

	override public function run(): Bool {
		var ret = super.run();
#if php
		Lib.println('</pre></body></html>');
#end
		return ret;
	}

}