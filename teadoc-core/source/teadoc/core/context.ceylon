
interface TeadocLoadout {
	
	shared formal void affect(TeadocContext cxt) ;
}

class TeadocScalar(shared Needle? needle, shared Object? initValue = null) {
	variable Object? injectValue = initValue ;
	shared Object? currentValue => injectValue ;

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
		
		if (exists needle) {
			Object v = needle.inject(rq) ;
			injectValue = v ;
			return v ;
		}

		else {
			return load(rq) ;
		}
	}

	shared void clear() {
		if (exists needle) { injectValue = null ; }
	}
}

class TeadocContext({TeadocLoadout | TeadocContext*} loadouts) {
	
	//TODO: load phase
	//TODO: force initialization
	//TODO: resolve injections
	//TODO: circular init protection
	//TODO: definitions -> function, needle, value, class, w/ addl post processing

	
	
}