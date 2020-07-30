(def str-replace clojure.string/replace)

(defn remove-comments
    [asm]
    (str-replace asm #";.*$" ""))

(defn translate-to-easm
				[asm]
				(-> asm
								(str-replace "int 0x80" "syscall")
								(str-replace "syscall" "easm--syscall")
								(str-replace #"mov eax,.{0,10}1(?![\s\S]*mov eax[\s\S]*)[\s\S]*easm--syscall" "easm--exit")))
