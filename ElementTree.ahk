/*
ElementTree - XML module
*/
class ElementTree extends ElementTree.__base__
{

	__New(dom:=false) {
		ObjInsert(this, "_", [])
		ObjInsert(this, "__dom__"
		       , (dom && dom.nodeType==9) ? dom : ComObjCreate(ElementTree.version))
		this.setProperty("SelectionLanguage", "XPath") ;for OS<VISTA|7|8
	}

	__Set(k, v, p*) {
		; using a 'Try' statement seems to put the block in an endless loop...
		if (n:=this.find(k)) {
			if ((typestr:=n.typestr) == "element") {
				; Change this to be consistenet with its '__Get' counterpart??
				prev := (n.text := v)
			}
			else if typestr in % "attribute,text,comment,cdatasection"
			{
				prev := n.nodeValue
				n.nodeValue := v
			}
			return prev
		}
		
		try return (this.__dom__)[k] := v
	}

	class __Get extends ElementTree.__property__
	{

		__(k, p*) {
			if (n:=this.find(k)) {
				typestr := n.typestr
				if typestr in % "document,element,documentfragment"
					return n
				else if typestr in % "attribute,text,comment,cdatasection"
					return n.text
				else return
			}
			
			try (res := (this.__dom__)[k])
			catch
				return
			return ElementTree.__wrap__(res)
		}

		len() {
			if !this.__dom__.hasChildNodes()
				return 0
			return this.findall("*").len
		}
		/*
		lenall() {
			if !(this.typestr ~= "^(ele|docu(mentfrag)?)ment$")
				throw Exception("lenall(): Node cannot contain child nodes.", 1)
			return this.findall("node()").len
		}
		*/
		root() {
			return this.find("/*")
			;return new ElementTree.Element(this.__doc__.documentElement)
		}

		type() {
			return this.__dom__.nodeType
		}

		typestr() {
			return this.__dom__.nodeTypeString
		}
		; ownerDocument := ElementTree object
		__doc__() {
			return this.find("/")
		}
	}

	__Call(m, p*) {
		static bif
		/*
		Do not initialize 'bif' as class static initializer(s) will not be
		able to access the variable's content when calling this function.
		*/
		if !bif ; Not #Warn friendly
			bif := "i)^i)^(Insert|Remove|M(in|ax)Index|(S|G)etCapacity|"
			     . "GetAddress|_NewEnum|HasKey|Clone)$"
		
		if (m = "findall")
			return this.find(p[1], true)

		else if ObjHasKey(ElementTree.__Get, m)
			return this[m, p*]
		
		else if (!ObjHasKey(ElementTree, m) && !(m ~= bif)) {
			for k, v in p
				if ElementTree.is_tree(v) ; ElementTree instance
				|| ElementTree.is_element(v) ; ElementTree.Element instance
				|| ElementTree.is_items(v) ; ElementTree.Items instance
					p[k] := v.__dom__
			try (res := (this.__dom__)[m](p*))
			catch
				return
			return ElementTree.__wrap__(res)
		}
	}

	parse(src) {
		if (f:=FileExist(src)) && !InStr(f, "D")
			throw Exception("Invalid XML source.", -1)
		et := new ElementTree()
		et.async := false, et.load(src)
		return et
	}

	fromstring(src) {
		if !(src ~= "s)^<.*>$")
			throw Exception("Invalid XML source.", -1)
		et := new ElementTree()
		et.async := false, et.loadXML(src)
		return et.root
	}
	/*
	Multi-purpose function
	*/
	add(xpr:=".", kwargs:="") {
		if !(self:=this.find(xpr))
			return false

		if !IsObject(kwargs) {
			if (kwargs ~= "i)^(?!(?:xml|[\d\W_]))[\w-:]+$") ; valid tag name
				return self.add({tag: kwargs})
			else if (SubStr(kwargs, 1, 1) == "<") && (SubStr(kwargs, 0) == ">")
				return self.add({xml: kwargs})
		}

		if (tag:=kwargs.HasKey("tag") ? kwargs.Remove("tag") : "") {
			c := this.__doc__.createElement(tag)
			if (ins:=kwargs.HasKey("ins") ? kwargs.Remove("ins") : "")
				self.insertBefore(c, IsObject(ins) ? ins : self.find(ins))
			else self.appendChild(c)
			c.add(kwargs)
			return c

		} else if (xml:=kwargs.HasKey("xml") ? kwargs.Remove("xml") : "") {
			c := this.__xml__(xml)
			if (ins:=kwargs.HasKey("ins") ? kwargs.Remove("ins") : "")
				self.insertBefore(c, IsObject(ins) ? ins : self.find(ins))
			else self.appendChild(c)
			
		} else {
			if (attrib:=kwargs.HasKey("attrib") ? kwargs.Remove("attrib") : "")
				self.attrib := attrib
			if (comment:=kwargs.HasKey("comment") ? kwargs.Remove("comment") : "")
				self.appendChild(this.__doc__.createComment(comment))
			if (sub:=kwargs.HasKey("sub") ? kwargs.Remove("sub") : "")
				for i, s in sub
					self.add(s)
			if (text:=kwargs.HasKey("text") ? "text" : (kwargs.HasKey("cdata") ? "cdata" : ""))
				self[text] := kwargs.Remove(text)
			/*
			Remaining key-value pairs are treated as attributes. If a key
			starts with an "@", the substring starting from pos 2 will be
			used as the attribute name.
			*/
			for k, v in kwargs
				self.setAttribute(SubStr(k, 1, 1) == "@" ? SubStr(k, 2) : k, v)
		}

	}
	/*
	Removes a node
	*/
	del(xpr:=".", n:=".") {
		if !(self:=this.find(xpr))
			return false
		
		if IsObject(n) && (n.base == ElementTree.Element)
			return self["remove" . (n.typestr == "attribute" ? "AttributeNode" : "Child")](n)
		else if (n >= 0 && n <= self.len)
			return self.del(self.find("*[" . n . "]"))
		else if (e:=self.find(n))
			return e.find("..").del(e)
	}
	/*
	Similar to selectSingleNode/selectNodes.
	Returns an 'ElementTree' or 'Element' instance.
	*/
	find(xpr, all:=false) {
		if (this.type ~= "^(7|10)$")
			return false
		if all
			return new ElementTree.Items(this.__dom__.selectNodes(xpr))
		
		else return (n:=this.__dom__.selectSingleNode(xpr))
		            ? ((n.nodeTypeString == "document")
		              ? new ElementTree(n)
		              : new ElementTree.Element(n))
		            : false
	}
	/*
	Alternative
	This is slower due to the redirected calls
	find(xpr, all:=false) {
		if all
			return this.selectNodes(xpr)
		else return this.selectSingleNode(xpr)
	}
	*/
	/*
	Generates a string representation of an XML element and its descendant(s)
	*/
	tostring(i:="", lvl:=0) {
		if !i ; if no indentation is specified, return 'xml' property
			return this.xml
		start := end := ""
		if this.findall("child::node()[not(self::text())]").len {
			n := "`n"
			if !lvl
				lvl := (this.typestr != "document" ? 1 : 0)
			Loop, % lvl
				t .= i
			
			if (this.typestr == "element")
				start := SubStr(this.xml, 1, InStr(this.xml, ">"))
				, end := SubStr(this.xml, InStr(this.xml, "<",, 0))
			
			for c in this.childNodes {
				try val := c.findall("child::node()[not(self::text())]").len
				           ? c.tostring(i, lvl+1)
				           : c.xml
				catch
					val := c.xml
				str .= val . n . t
			}
			str := (lvl ? n . t : "") . Trim(str, "`n`t ") . n . SubStr(t, StrLen(i)+1)
		
		} else str := this.xml

		return start . str . end
	}

	class Element
	{

		__New(elem) {
			ObjInsert(this, "_", [])
			ObjInsert(this, "__dom__", elem)
		}

		_NewEnum() {
			typestr := this.typestr
			if typestr in % "document,element,documentfragment"
				; Matches all 'element' child nodes only, change to 'node()'?
				return this.findall("*")._NewEnum()
		}

		__Set(k, v, p*) {
			if  (k = "attrib") {
				if (this.typestr != "element")
					return
				/*
				An array [] may be specified to add attributes in the order they
				were specified, not alphabetically.
				e.g.: element.attrib := ["nameX", "valueX", "nameA", "valueA"]
				*/
				for i in v
					arr := (i == A_Index)
				until !arr
				for a, b in v {
					if arr {
						if !Mod(A_Index, 2)
							this.setAttribute(key, b)
						else key := b
					} else this.setAttribute(a, b)
				}
				return
			}

			else if k in % "cdata,cdatasection,text"
			{
				typestr := this.typestr
				if typestr not in % "document,element,documentfragment"
					return (k = "text") ? this["."] := v : ""
				if (t:=this.find("text()")) {
					res := t.text
					, (k = "text") ? t.text := v
					               : (t.typestr == "text" ? "" : t.text := v)
				} else {
					res := (this.__doc__)["create" . (k="text" ? "TextNode" : "CDATASection")](v)
					this.len ? this.insertBefore(res, this[1])
					         : this.appendChild(res)
					;res := new ElementTree.Element(t)
				}
				return res
			}
			
			else return ElementTree.__Set.(this, k, v, p*)
		}

		class __Get extends ElementTree.__property__
		{

			__(k, p*) {
				; 'k' is index of 'element' child node
				if (Abs(k) != "") && (k <= (len:=this.len))
					; Match 'element' nodes only
					return this.find("*[" . (k>0 ? k : len+k) . "]")
					; slower (maybe XPath 'last()'??)
					;return this.find("*[" . (k>0 ? k : "last()-" k*-1) . "]")

				else if k in % "atrributes,baseName,childNodes,dataType,definition,"
				             . "firstChild,lastChild,name,namespaceURI,nextSibling,"
				             . "nodeName,nodeTypedValue,nodeTypeString,nodeValue,"
				             . "ownerDocument,parentNode,parsed,prefix,previousSibling,"
				             . "specified,tagName,text,value,xml"
				/*
				else if (k ~= "i)^(attributes|baseName|childNodes|dataType|"
				            . "definition|(first|last)Child|name(spaceURI)?|"
				            . "(next|previous)Sibling|node(Name|Type(dValue|"
				            . "String)?|Value)|ownerDocument|par(entNode|sed)|"
				            . "prefix|specified|tagName|text|value|xml)$")
				*/
				{
					try res := (this.__dom__)[k, p*]
					catch
						return
					return ElementTree.__wrap__(res)
				}
				
				else return ObjHasKey(ElementTree.__Get, k)
				            ? ElementTree.__Get[k].(this, p*)
				            : ElementTree.__Get.__.(this, k, p*)
			}

			attrib(p*) {
				if (this.typestr != "element")
					return
				;attrib := new ElementTree.Items(this.__dom__.attributes)
				attrib := this.attributes
				return p.MinIndex() ? attrib.getNamedItem(p[1]).value : attrib
			}

			tree() {
				return this.find("/")
			}
			
			tag() {
				if (this.typestr != "element")
					throw Exception("Type mismatch. Not an 'element' node.", -1)
				return this.nodeName
			}

			text() {
				typestr := this.typestr
				if typestr not in % "document,element,documentfragment"
					return this.__dom__.text
				return this.find("text()").text
			}
		}

		__Call(m, p*) {
			if (m = "findall")
				return this.find(p[1], true)

			else if ObjHasKey(ElementTree, m)
				return ElementTree[m].(this, (m~="i)^(add|del)$" ? [".", p*] : p)*)

			else if ObjHasKey(ElementTree.Element.__Get, m)
				return this[m, p*]

			else if ObjHasKey(ElementTree.__Get, m)
				return ElementTree.__Get[m].(this, p*)

			else if m in % "appendChild,cloneNode,getAttribute,getAttributeNode,"
			             . "getElementsByTagName,hasChildNodes,insertBefore,normalize,"
			             . "removeAttribute,removeAttributeNode,removeChild,replaceChild,"
			             . "selectNodes,selectSingleNode,setAttribute,setAttributeNode,"
			             . "transformNode,transformNodeToObject"
			/*
			else if (m ~= "i)^((append|remove|replace)Child|cloneNode|"
			            . "get(Attribute(Node)?|ElementsByTagName)|"
			            . "hasChildNodes|insertBefore|normalize|"
			            . "removeAttribute(Node)?|select(Nodes|SingleNode)|"
			            . "setAttribute(Node)?|transformNode(ToObject)?)$")
			*/
			{
				for k, v in p
					if ElementTree.is_tree(v)    ; ElementTree instance
					|| ElementTree.is_element(v) ; ElementTree.Element instance
					|| ElementTree.is_items(v)   ; ElementTree.Items instance
						p[k] := v.__dom__
				try (res := (this.__dom__)[m](p*))
				catch
					return
				return ElementTree.__wrap__(res)
				;try return (this.__dom__)[m](p*)
			}
		}
	}

	class Items
	{

		__New(list) {
			ObjInsert(this, "__dom__", list)
		}

		class __Get extends ElementTree.__property__
		{

			__(k, p*) {
				if (Abs(k) != "") && (k <= (len:=this.len))
					return new ElementTree.Element(this.item((k>0 ? k : len+k)-1))
					;return new ElementTree.Element(this.item((len+(k>0 ? (k-len) : k))-1))
				/*
				; Get rid of this??
				else if (this.typestr == "namednodemap" && ni:=this.getNamedItem(k))
					return ni.value
				*/
				else if k in % "context,expr,length"
					try return (this.__dom__)[k, p*]
			}

			len() {
				return this.__dom__.length
			}

			typestr() {
				type := SubStr(ComObjType(this.__dom__, "Name"), 8)
				StringLower, type, type
				return type
			}
		}

		__Call(m, p*) {
			if ObjHasKey(ElementTree.Items.__Get, m)
				return this[m, p*]
			
			else if m in % "clone,getNamedItem,getProperty,getQualifiedItem,item,"
			             . "matches,nextNode,peekNode,removeAll,removeNext,reset,"
			             . "setNamedItem"
			/*
			else if (m ~= "i)^(((get|remove)(Named|Qualified))?Item|matches|"
			            . "(next|peek)Node|re(set|move(All|Next))|setNamedItem|"
			            . "clone|getProperty)$")
			*/
				try return (this.__dom__)[m](p*)
		}

		_NewEnum() {
			return new ElementTree.Items.enumerator(this)
		}

		class enumerator
		{
			__New(obj) {
				this.obj := obj
				this.len := obj.len
				this.idx := 0
			}

			Next(ByRef k, ByRef v:="") {
				i := this.idx += 1
				if (i <= this.len) {
					if (this.obj.typestr == "namednodemap" && IsByRef(v))
						k := this.obj[i].name, v := this.obj[i].value
					else k := this.obj[i]
				
				} else this.idx := i := 0
				return i
			}
		}
	}

	__xml__(str) {
		root := ElementTree.fromstring("<ET>" . str . "</ET>")
		n := root.tree.importNode(root, true)
		dom := (n.childNodes.length>1)
		       ? this.__doc__.createDocumentFragment()
		       : n.removeChild(n.firstChild)

		while n.hasChildNodes()
			dom.appendChild(n.removeChild(n.firstChild))

		return dom
	}
	
	class __base__
	{

		class __Get extends ElementTree.__property__
		{

			__(k, p*) {

			}

			version() {
				static MSXML := ElementTree.version

				if !MSXML
					MSXML := "MSXML2.DOMDocument"
					      . ((A_OsVersion~="^WIN_(VISTA|7|8)$") ? ".6.0" : "")
				return MSXML
			}
		}

		__Call(m, p*) {
			if m in % "is_tree,is_element,is_items"
			{
				if (ComObjType(p[1]) == 9)
					return false
				__base__ := {t:ElementTree
				           , e:ElementTree.Element
				           , i:ElementTree.Items}[SubStr(m, 4, 1)]
				return (p[1].base == __base__)
			}
		}
		/*
		Wraps a COM object(IXMLDOM) into an ElementTree-compatible object
		Current version returns the same object if 'type' is not wrappable
		*/
		__wrap__(obj) {
			if !IsObject(obj) || (ComObjType(obj) != 9)
				return obj
			type := ComObjType(obj, "Name")
			if (type ~= "^(IXML)?DOMDocument(2|3)?$") ;fix this
				return new ElementTree(obj)
			
			else if (type == "IXMLDOMNode")
				return (obj.nodeType == 9)
				       ? new ElementTree(obj)
				       : ((obj.nodeType ~= "^(11?|[2-478])$")
				         ? new ElementTree.Element(obj) : obj)
			
			else if type in % "IXMLDOMAttribute,IXMLDOMCDATASection,IXMLDOMComment,"
			                . "IXMLDOMElement,IXMLDOMDocumentFragment,"
			                . "IXMLDOMProcessingInstruction,IXMLDOMText"
				return new ElementTree.Element(obj)
			
			else if type in % "IXMLDOMNamedNodeMap,IXMLDOMNodeList,IXMLDOMSelection"
				return new ElementTree.Items(obj)
			
			else return obj
		}
	}

	class __property__
	{
		__Call(target, name, params*) {
			if name not in % "base,__Class"
			{
				return ObjHasKey(this, name)
				       ? this[name].(target, params*)
				       : this.__.(target, name, params*)
			}
		}
	}
}