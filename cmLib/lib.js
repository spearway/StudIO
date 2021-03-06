import libCM from "./libBin.js"

const EditorState = libCM.EditorState
const EditorView = libCM.EditorView
const EditorSelection = libCM.EditorSelection
const keymap = libCM.keymap
const history = libCM.history
const redo = libCM.redo
const redoSelection = libCM.redoSelection
const undo = libCM.undo
const undoSelection = libCM.undoSelection
const lineNumbers = libCM.lineNumbers
const baseKeymap = libCM.baseKeymap
const indentSelection = libCM.indentSelection
const legacyMode = libCM.legacyMode
const matchBrackets = libCM.matchBrackets
const specialChars = libCM.specialChars
const multipleSelections = libCM.multipleSelections
const text = libCM.text

import completion from "./completion/index.js"
import autocomplete from "./plugin/autocomplete.js"
import plugin from "./plugin/plugin.js"
import {
	Notification,
	NotificationCenter
} from "./components/broadcast.js"
import BufferCenter from "./components/buffer.js"
import expand from './components/emmet.es.js';

class editor {
	constructor(ext, value, settings) {
		settings = typeof settings != "undefined" ? settings : {}
		this.plugins = []

		this.EditorSettings = settings

		// Notifications

		NotificationCenter.default.addObserver("registerPlugin", this.registerPlugin.bind(this))
		NotificationCenter.default.addObserver("fontSize", this.fontSize.bind(this))

		// Clearing view
		this.clear()
		if (ext == null && value == null) {
			document.addEventListener("DOMContentLoaded", function () {
				// Do something...
			})
		} else {
			let mode = CodeMirror.findModeByExtension(ext)
			if (typeof mode == "undefined" || typeof mode.mode == "undefined") {
				mode = CodeMirror.findModeByExtension("md") // Using markdown for undefined var
			}

			const script = document.createElement('script');
			script.onload = function () {
				var m = null
				try {
					m = ExportedMode({
						indentUnit: 2
					})
				} catch (e) {
					if (typeof ExportedMode != "undefined") {
						m = ExportedMode({
							indentUnit: 2
						}, {})
					} else {
						alert(e)
					}
				}

				let mode = legacyMode({
					mode: m
				})

				if (typeof ExternalMode != "undefined") {
					mode = legacyMode({
						mode: ExternalMode({
							indentUnit: 2
						}, {})
					})
				}

				this.mode = mode

				let isMac = /Mac/.test(navigator.platform)

				let exts = [
					lineNumbers(),
					history(),
					specialChars(),
					multipleSelections(),
					mode,
					matchBrackets(),
					keymap({
						"Mod-z": undo,
						"Mod-Shift-z": redo,
						"Mod-u": function (view) {
							return undoSelection(view) || true
						},
						[isMac ? "Mod-Shift-u" : "Alt-u"]: redoSelection,
						"Ctrl-y": isMac ? undefined : redo,
						"Shift-Tab": indentSelection
					}),
					keymap(baseKeymap),
				]

				this.cm = EditorState.create({
					doc: atobUTF8(value),
					extensions: exts
				})
				let view = window.view = new EditorView({
					state: this.cm
				})

				this.clear()

				document.querySelector("#editor").appendChild(view.dom)
				document.querySelector(".tip").style.display = "none"
				this.listenForAutomcompletion()
				const restricted = ["MD", "TXT", "RTF"]
				if (restricted.indexOf(ext) == -1) {
					this.disableCompletion()
				}

				BufferCenter.default.execute(window.e)
				NotificationCenter.default.post(new Notification("fontSize", window.EditorSettings.fontSize))
			}.bind(this);
			script.src = `mode/${mode.mode}/${mode.mode}.js`;

			document.head.appendChild(script);
		}
	}
	disableCompletion() {
		const content = document.querySelector(".codemirror-content")
		content.setAttribute("autocorrect", "off")
		content.setAttribute("autocapitalize", "off")
	}

	settings() {
		try {
			this.lineWrapping = this.EditorSettings.lineWrapping == true // boolean convert
			this.theme = this.EditorSettings.theme
		} catch (e) {
			console.warn(e)
		}
		if (typeof this.theme != "undefined") {
			this.loadTheme(this.theme)
		}
	}
	loadTheme(theme) {
		const link = document.createElement("link")
		link.setAttribute("rel", "stylesheet")
		link.setAttribute("href", `theme/${theme}.css`)
		document.head.appendChild(link);
		if (typeof this.cm != "undefined") {
			// this.cm.setOption("theme", theme)
		}
	}
	fontSize(v) {
		if (v > 0) {
			document.querySelector("#editor").style["font-size"] = `${v}px`
		}
	}

	clear() {
		document.body.innerHTML = "<div class=\"tip\">Open a document</div><div id=\"editor\"></div>"
		if (window.Sk != "undefined") {
			document.body.innerHTML += "<button type=\"button\" onclick=\"runit()\">▶</button><pre id=\"output\"></pre><div id=\"mycanvas\"></div>"
		}
	}
	load(file) {
		this.clear()
		if (typeof this.cm == "undefined") {
			setTimeout(function () {
				this.load(file)
			}.bind(this), 16) // Waiting 16ms (~ 1 frame) before rendering for letting WKWebView parse and process everything. Otherwise, we do it again and again.
		} else {
			const str = atobUTF8(file)

			const doc = text.of(str, "\n")
			window.view.state.doc = doc
			window.view.setState(window.view.state)
		}
	}
	save() {
		return btoaUTF8(window.view.state.doc.toString())
	}
	getLangName() {
		return this.mode.name
	}

	insertSnippet(snippet, replaceLine) {
		replaceLine = typeof replaceLine != "undefined" ? replaceLine : false
		const str = atobUTF8(snippet)
		document.querySelector(".codemirror-content").focus()
		if (replaceLine === true) {
			for (var i = 0; i < this.c.getLastToken()[0].length; i++) {
				document.execCommand('delete')
			}
		}
		document.execCommand('insertText', false, str)
	}
	enablePreview(ext) {
		// Load TexLive.js
		const script = document.createElement('script');
		document.body.innerHTML = "<div class=\"tip\">Loading</div>"
		script.onload = () => {
			if (ext == "tex") {
				// const pdftex = new PDFTeX();
				const latex_code = window.view.state.doc.toString()
				// pdftex.compile(latex_code).then(pdf => {
				// 	window.location = pdf
				// })
				window.location = `https://latexonline.cc/compile?text=${encodeURIComponent(latex_code)}`
			} else if (ext == "md") {
				const converter = new showdown.Converter()
				const text = window.view.state.doc.toString()
				const html = converter.makeHtml(text);
				document.body.innerHTML = "<div class=\"markdown-body\">Loading</div>"
				document.querySelector(".markdown-body").innerHTML = html
			}
		}
		if (ext == "tex") {
			script.src = `TexLive/pdftex.js`;
		} else if (ext == "md") {
			script.src = `./showdown.js`;
			const link = document.createElement('link');
			link.rel = "stylesheet"
			link.href = "./ghmd.css"
			document.head.appendChild(link);
		}

		document.head.appendChild(script);
	}
	moveLineDown() {
		if (window.view.state.doc.toString() == "") return ""
		const index = window.view.state.selection.ranges[0].anchor
		let line = view.state.doc.lineAt(index)
		const content = line.content
		let nextLine = view.state.doc.lineAt(line.end + 1)
		const transaction1 = view.state.t().replace(line.start, line.end, nextLine.content)
		const midstate = transaction1.apply()
		line = midstate.doc.lineAt(line.start)
		nextLine = midstate.doc.lineAt(line.end + 1)
		const transaction2 = midstate.t().replace(nextLine.start, nextLine.end, content)
		window.view.setState(transaction2.apply())
	}
	moveLineUp() {
		if (window.view.state.doc.toString() == "") return ""
		const index = window.view.state.selection.ranges[0].anchor
		let line = view.state.doc.lineAt(index)
		const content = line.content
		let nextLine = view.state.doc.lineAt(line.start - 1)
		const transaction1 = view.state.t().replace(line.start, line.end, nextLine.content)
		const midstate = transaction1.apply()
		line = midstate.doc.lineAt(line.start)
		nextLine = midstate.doc.lineAt(line.start - 1)
		const transaction2 = midstate.t().replace(nextLine.start, nextLine.end, content)
		window.view.setState(transaction2.apply())
	}

	listenForAutomcompletion() {
		if (typeof this.c == "undefined") {
			this.c = new completion(window.view.state.doc.toString())
		} else if (typeof this.c.init != "undefined") {
			this.c.init(window.view.state.doc.toString())
		}
		const parseAndPropose = async function () {
			const currentWord = this.c.getLastToken()
			const suggestions = this.c.getSuggestions(currentWord[0], this.c.getContent(currentWord[0], currentWord[1]))
			this.setCompletion(...suggestions)
		}.bind(this)
		document.querySelector(".codemirror-content").addEventListener("input", () => parseAndPropose())
	}
	setCompletion(a, b, c) {
		window.webkit.messageHandlers.completion.postMessage([a, b, c])
	}

	expandEmmet(src) {
		const text = expand(src)
		const b64 = btoaUTF8(text)
		this.insertSnippet(b64)
	}

	registerPlugin({
		obj,
		type
	}) {
		this.plugins.push(new obj(type))
		if (type == "hint") {
			this.c = this.plugins[this.plugins.length - 1]
			window.webkit.messageHandlers.setKeys.postMessage(this.c.getSmartKeys())
		}
	}
	execute(f) {
		f()
	}
}
export default {
	editor: editor,
	Text: text,
	Completion: completion,
	add: function (obj, type) {
		BufferCenter.default.addTask("execute", () => {
			const plugin = new Notification("registerPlugin", {
				obj: obj,
				type: type
			})

			NotificationCenter.default.post(plugin)
		})
	},
	plugin: plugin,
	autocomplete: autocomplete,
	BufferCenter: BufferCenter
}