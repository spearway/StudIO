import levenshtein from "./levenshtein.js"
class Completion {
	constructor(value = "") {
		this.tokenize(value).then(tokens => {
			tokens.filter(a => a != "")
			this.set = new Set(tokens)
		})
	}
	tokenize(str) {
		return new Promise((resolve, reject) => {
			resolve(str.replace(/[^\w\d\s]/g, " ")
				.replace(/\s{2,}/g, " ")
				.split("\n")
				.join(" ")
				.split(" "))
		});
	}
	appendToSet(content) {
		this.tokenize(content).then(tokens => {
			tokens.forEach(token => {
				if (token != "") {
					this.set.add(token)
				}
			})
		})
	}
	getSuggestions(currentWord, content) {
		if (typeof content != "undefined" && this.set.size < 3 && content != "") {
			this.appendToSet(content)
		}
		currentWord = currentWord.trim()
		let scores = [
			["", Number.MAX_SAFE_INTEGER],
			["", Number.MAX_SAFE_INTEGER],
			["", Number.MAX_SAFE_INTEGER]
		]
		this.set.forEach(token => {
			if (token == "") return
			const length = currentWord.length
			const truncated = token.substring(0, length)
			const score = levenshtein(truncated, currentWord)
			scores.push([token, score])
		})
		scores.sort((a, b) => a[1] - b[1])
		return scores.slice(0, 3).map(x => x[0])
	}

	getLastToken() {
		if (window.view.state.doc.toString() == "") return ""
		const index = window.view.state.selection.ranges[0].anchor
		const content = window.view.state.doc.toString()

		let out = ""
		for (let i = 1; true; i++) {
			const newI = index - i

			if (newI == 0) break
			if (newI < 0) {
				newI = content.length - 1
			}
			const letter = content[newI]

			if (/[^\w\d\s]/g.test(letter) == true) break
			if (typeof letter != "undefined") {
				out += letter
			}
		}
		return [out.split("").reverse().join("").trim(), newI]
	}

	getContent({
		length
	}, lastI) {
		const content = window.view.state.doc.toString()

		return content.slice(0, lastI) + content.slice(lastI + length, content.length);
	}
}

export default Completion
