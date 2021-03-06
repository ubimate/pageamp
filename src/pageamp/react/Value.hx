/*
 * Copyright (c) 2018-2019 Ubimate Technologies Ltd and PageAmp contributors.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

package pageamp.react;

import hscript.Expr;
import hscript.Parser;
import pageamp.util.Observable;
import pageamp.util.DoubleLinkedItem;

using pageamp.util.ArrayTool;

// function arguments: userdata, nativeName, value
typedef ValueCallback = Dynamic->String->Dynamic->Void;

class Value extends DoubleLinkedItem {
	public static inline var MAX_DEPENDENCY_DEPTH = 100;
	public var name: String;
	public var nativeName: String;
	public var scope: ValueScope;
	public var uid: String;
	public var source: String;
	public var value: Dynamic;
	public var prevValue: Dynamic; // only valid during `cb` calls
	public var valueFn: Void->Dynamic;
	public var cycle: Int;
	public var userdata: Dynamic;
	public var cb: ValueCallback;
	public var first = true;

	public function new(value:Dynamic,
	                    name:Null<String>,
	                    nativeName:Null<String>,
	                    scope:ValueScope,
	                    ?userdata:Dynamic,
	                    ?cb:ValueCallback,
	                    callOnNull=true,
	                    ?valueFn:Void->Dynamic) {
		super();
		this.uid = scope.context.newUid();
		this.name = (name != null ? name : uid);
		this.nativeName = nativeName;
		this.scope = scope;
		this.userdata = userdata;
		reset(value, cb, callOnNull, valueFn);
		scope.addValue(this);
    }

	public function reset(value:Dynamic,
						  ?cb:ValueCallback,
						  callOnNull=true,
						  ?valueFn:Void->Dynamic) {
		this.valueFn = valueFn;
		source = null;
		exp = null;
		cycle = 0;
		var ref:ValueRef = null;
#if hscriptPos
		if (Std.is(value, ValueRef)) {
			ref = untyped value;
			value = ref.val;
		}
#end
		if (Std.is(value, String) && !ValueParser.isConstantExpression(value)) {
			this.source = value;
			var s = ValueParser.patchLF(value);
			if (ValueParser.FUNCTION_RE.match(s)) {
				var on = ValueParser.FUNCTION_RE.matched(2);
				var args = ValueParser.FUNCTION_RE.matched(3);
				var body = ValueParser.FUNCTION_RE.matched(4);
				on = ValueParser.unpatchLF(on);
				args = ValueParser.unpatchLF(args);
				body = ValueParser.unpatchLF(body);
				Log.value('new(): parsed function: [$on] ($args) -> {$body}');
				var keys = ~/\s*,\s*/.split(StringTools.trim(args));
				var e = parseString(body, ref);
				if (e != null) {
					on == 'undefined' ? on = null : null;
					if (on != null) {
						// handler
						//this.source = "${" + on + "}";
						exp = parseString(on, ref);
						cb = function(u:Dynamic, k:String, v:Dynamic) {
							Log.value('parsed handler activated with ' + v);
							var locals = new Map<String,Dynamic>();
							if (keys.length > 0) {
								locals.set(keys[0], v);
							}
							scope.context.interp.evaluateWith(e, scope, locals);
						}
					} else {
						// method
						this.value = Reflect.makeVarArgs(
									function(v:Array<Dynamic>) {
							var loc = new Map<String,Dynamic>();
							var count = 0, len = v.length;
							for (key in keys) {
								loc.set(key, (count < len ? v[count++] : null));
							}
							var res = scope.context.interp.evaluateWith(e,
									scope, loc);
							Log.value('parsed function result: $res');
							return res;
						});
					}
				}
			} else {
				var sb = new StringBuf();
				try {
					ValueParser.parse(value, sb);
					Log.value('new(): parsed expression: ${sb.toString()}');
				} catch (ex:Dynamic) {
					Log.value('new(): $ex');
				}
				exp = parseString(sb.toString(), ref);
			}
		} else {
			this.value = value;
		}
		this.cb = (callOnNull ? cb : function(u,n,v) if (v != null) cb(u,n,v));
	}

	function parseString(code:String, ref:ValueRef): Expr {
		var ret:Expr = null;
		try {
			ret = scope.context.parseString(code);
		} catch (ex:Dynamic) {
#if hscriptPos
			if (ref != null && Std.is(ex, Error)) {
				ref.log(cast ex, ref);
			}
#end
			Log.value('parseString() [$code]: $ex');
		}
		return ret;
	}

	public function dispose(): Value {
		scope.removeValue(this);
		return null;
	}

	#if !debug inline #end
	public function isDynamic(): Bool {
		return (exp != null || valueFn != null);
	}

	public function get(): Dynamic {
		Log.value('${name}.get()');
		refresh();
		if (scope.context.isRefreshing) {
			// while refreshing, get() performs a "dependencies pull"
			var v:Value = scope.context.stack.peek();
			if (v != null) {
				// we're being pulled by a dynamic value: make it observe us
				addObserver(v.observer);
			}
		}
		return value;
	}

	public function get0() {cycle = 0; get();}
	public function get1(_) {cycle = 0; get();}
	public function get2(a, b) {cycle = 0; get();}
	public function get3(a, b, c) {cycle = 0; get();}
	public function evGet(ev) {
		if (ev != null) {
			cycle = 0; scope.set('ev', ev, false); get();
		}
	}

	public function set(v:Dynamic) {
		Log.value('${name}.set("$v")');
		var oldValue = value;
		if (_set(v) && !scope.context.isRefreshing) {
			// while not refreshing, set() performs a "dependencies push"
			var depth = scope.context.enterValuePush();
			if (depth == 1) {
				scope.context.nextCycle();
				cycle = scope.context.cycle;
			}
			if (depth <= MAX_DEPENDENCY_DEPTH && observable != null) {
				observable.notifyObservers(this, oldValue);
			}
			scope.context.exitValuePush();
		}
	}

	public inline function trigger() {
		first = true;
		set(value);
	}

	public function clearObservers() {
		if (observable != null) {
			observable.clearObservers();
		}
	}

	#if !debug inline #end
	public function refresh(force=false) {
		Log.value('${name}.refresh()');
		if (cycle != scope.context.cycle || force) {
			cycle = scope.context.cycle;
			if (isDynamic()) {
				if (scope.context.isRefreshing) {
					//
					// By executing our expression, we might call the `get()`
					// method of other values: by pushing ourselves onto the
					// stack they can trace us as dependent on them and add us
					// to their list of observers (they "pull" our dependency).
					//
					// Outside of refresh cycles, observers are notified by the
					// set() method when a value changes, thus propagating the
					// change to all dependent values (it "pushes" the change).
					//
					scope.context.stack.push(this);
				}
				try {
					var v = null;
					if (valueFn != null) {
						v = valueFn();
					} else {
						v = scope.context.interp.evaluate(exp, scope);
					}
					Log.value('${name}.refresh(): $v');
					set(v);
				} catch (ex:Dynamic) {
					Log.value('${name}.refresh() error: $ex');
				}
				if (scope.context.isRefreshing) {
					scope.context.stack.pop();
				}
			} else if (first) {
				_set(value);
			}
		}
	}

	#if !debug inline #end
	public function setObservableCallback(cb:Int->Void) {
		if (observable == null) {
			observable = new Observable();
		}
		observable.setCallback(cb);
	}

	// =========================================================================
	// public static
	// =========================================================================

	#if !debug inline #end
	public static function isConstantExpression(s:Dynamic): Bool {
		return ValueParser.isConstantExpression(s);
	}

	// =========================================================================
	// private
	// =========================================================================
	var observable: Observable;
	var exp: Expr;

	function _set(v:Dynamic): Bool {
		if (v != value || first) {
			prevValue = value;
			value = v;
			first = false;
			cb != null ? cb(userdata, nativeName, v) : null;
			prevValue = null;
			return true;
		}
		return false;
	}

	// called only at `push` time (i.e. outside of refreshes)
	function observer(s:Value, oldValue:Dynamic) {
		Log.value('${name}.observer() old: "$oldValue", new: "${s.value}"');
		get();
	}

	// called only at `pull` time (i.e. during refreshes)
	#if !debug inline #end
	function addObserver(o:Observer) {
		if (observable == null) {
			observable = new Observable();
		}
		observable.addObserver(o);
	}

}

#if hscriptPos
typedef ValueLog = Error->ValueRef->Void;
class ValueRef {
	public var val(default,null): Dynamic;
	public var src(default,null): Dynamic;
	public var log(default,null): ValueLog;

	public function new(val:Dynamic, src:Dynamic, log:ValueLog) {
		this.val = val;
		this.src = src;
		this.log = log;
	}
}
#else
typedef ValueLog = Dynamic;
typedef ValueRef = Dynamic;
#end
