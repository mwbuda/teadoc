import ceylon.collection { 
	MutableMap, HashMap,
	MutableSet, HashSet 
}

interface TeadocLoadout {
	
	shared formal void loadContext(PatternType? root, TeadocContext cxt) ;
}

class TeadocScalar(shared Needle initNeedle, shared Object? initValue = null) {
	variable Object? injectValue = initValue ;
	variable Needle currentNeedle = initNeedle ;
	shared Needle needle => currentNeedle ;
	shared Object? currentValue => injectValue ;

	shared void rebindNeedle(Needle nn) {
		if ( currentNeedle != nn ) {
			clear() ;
			currentNeedle = nn ;
		}
	}

	shared Object load(InjectRequest rq) {
		Object? v = injectValue ; 
		if (exists v) {
			return v ;
		}
		else {
			return reload(rq) ;
		}
	}

	shared Object reload(InjectRequest rq) {
		Object v = needle.inject(rq) ;
		injectValue = v ;
		return v ;
	}

	shared void clear() {
		injectValue = null ; 
	}
}

class TeadocContext() 
satisfies TeadocLoadout {
	
	//TODO: circular init protection

	MutableSet<TeadocKey> declared = HashSet<TeadocKey>() ;
	MutableMap<TeadocPattern, Needle> defineMappings = HashMap<TeadocPattern, Needle>() ;
	MutableMap<TeadocKey,TeadocPattern> patternMappings = HashMap<TeadocKey, TeadocPattern>() ;
	MutableMap<TeadocKey,TeadocScalar> bindingMappings = HashMap<TeadocKey, TeadocScalar>() ;

	shared Object? resolve(KeyType refkey, Boolean reload = false) {
		TeadocKey key = patternSchema.compileKey(refkey) ;
		
		InjectRequest request ;
		
		TeadocScalar? currRecord = bindingMappings.get(key) ;
		Boolean haveRecord = !(currRecord is Null) ;
		
		[TeadocPattern*] ellibiblePatterns = patternSchema.elligiblePatterns(key, defineMappings.keys) ;
		Boolean havePattern = !(ellibiblePatterns[0] is Null) ;
		
		if (!haveRecord && !havePattern) {
			return null ;
		}
		
		TeadocPattern pattern = ellibiblePatterns[0] else patternSchema.compilePattern(key) ;
		Needle needle = defineMappings.get(pattern) else ErrorInjection() ;
		TeadocScalar useRecord = currRecord else TeadocScalar(needle) ;
		
		if (reload) { useRecord.rebindNeedle(needle); }
		
		request = InjectRequest(key, pattern, this) ;
		return reload then useRecord.reload(request) else useRecord.load(request) ;
	}

	shared void add(TeadocLoadout|TeadocContext loadout, PatternType? root = null) {
		loadout.loadContext(root, this);
	}

	shared actual void loadContext(PatternType? root, TeadocContext cxt) {
		for (pattern->needle in defineMappings) {
			cxt.define(pattern, needle) ;
		}
		for (key in patternMappings.keys) {
			cxt.declare(key) ;
		}
	}

	shared void define(PatternType key, Needle callback) {
		TeadocPattern pk = TeadocPattern(key) ;
		defineMappings.put(TeadocPattern(key), callback ) ;
		
		//if it IS NOT abstract; create concrete bindings for reference
		if (!pk.isAbstract) {
			declared.add(TeadocKey(pk.string)) ;
			patternMappings.put(TeadocKey(pk.string), pk) ;
			bindingMappings.put(TeadocKey(pk.string), TeadocScalar(callback)) ;
		}
	
		//if it IS abstract; look over declared items and try to get concrete bindings for them instead.
		else {
			for (sk in patternMappings.keys.filter(pk.match)) {
				patternMappings.put(sk,pk) ;
				bindingMappings.put(sk, TeadocScalar(callback)) ;
			}
		}
	}
	
	shared void declare(KeyType key) {
		declared.add(TeadocKey(key)) ;
	}

	shared void forceContextLoad() {
		for (TeadocKey key in declared) {
			resolve(key) ;
		}
	}
	
	shared void forceContextReload() {
		for (TeadocKey key in declared) {
			resolve(key,true) ;
		}
	}
	
}