# cl-text-splitter
> A Common Lisp text splitting library

Usage
------

`text-splitter` is available via [ocicl](https://github.com/ocicl/ocicl).  Install it like so:
```
$ ocicl install text-splitter
```

Load and split documents like so:
```
(split (make-document-from-file "report.pdf"))
```
This will produce a list of strings split from `report.pdf` using the default size and overlap values (5000 and 200 characters respectively).

You can also create document instances manually like so:
```
(split (make-instance 'html-document :text MY-HTML-STRING) :size 10000 :overlap 0)
```

The `split` function will take advantage of document structure as it
computes the splits, which is why it is helpful to know what kind of
document we're splitting.

`split` will return `nil` if it doesn't recognize the document type.

Related Projects
-----------------

Related projects include:
* [cl-embeddings](https://github.com/atgreen/cl-embeddings): an LLM embeddings library
* [cl-chroma](https://github.com/atgreen/cl-chroma): for a Lisp interface to the [Chroma](https://www.trychroma.com/) vector database.
* [cl-completions](https://github.com/atgreen/cl-completions): an LLM completions library
* [cl-chat](https://github.com/atgreen/cl-chat): a wrapper around `completions` to maintain chat history,

Author and License
-------------------

``cl-text-splitter`` was written by [Anthony
Green](https://github.com/atgreen) and is distributed under the terms
of the MIT license.
