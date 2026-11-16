import json, sys

doc_file, question = sys.argv[1], sys.argv[2]
doc = open(doc_file, encoding="utf-8").read()

src = open("crew.jsonc", encoding="utf-8").read()
head = src[:src.rfind('"inputs"')]
block = '"inputs": ' + json.dumps({"doc": doc, "question": question},
                                  ensure_ascii=False, indent=2) + "\n}\n"
open("crew.jsonc", "w", encoding="utf-8").write(head + block)
print("inputs updated:", doc_file, "|", question)
print()
print("Now you can Run the CrewAI run !")