
import ceylon.language.meta.model { ... }

/*
 top level generic definitions

*/

alias Injection => Object(InjectRequest) ;
alias PostProcessing => Object(Object, InjectRequest) ;

class InjectRequest(
	shared TeadocKey key, 
	shared TeadocPattern pattern, 
	shared TeadocContext context
) {
	shared [String*] keyVariables => pattern.extractFromKey(key) ;
}

interface Needle 
satisfies Identifiable {
	shared formal Object inject(InjectRequest rq) ;

	//TODO: allow this to take in a sequence of post processing, instead of just one.
	//	will create more efficent data struct internally
	shared Needle with(PostProcessor | PostProcessing pp) => PostProcessed(this,{pp}) ;
}

interface PostProcessor {
	shared formal Object postProcess(Object bean, InjectRequest rq) ;
}

/**
 	needle with post processing
*/
class PostProcessed(Needle wrapped, {PostProcessor | PostProcessing+} postProcessors)
satisfies Needle {
	shared actual Object inject(InjectRequest rq) {
		variable Object bean = wrapped.inject(rq) ;
		for (pp in postProcessors) { 
			if (is PostProcessor pp) { bean = pp.postProcess(bean,rq) ; }
			else if (is PostProcessing pp) { bean = pp(bean,rq) ; }
		}
		return bean ;
	}
}

/**
	a teadoc scalar is a binding between an injection/needle and the cached resolved value of that needle once it is executed
*/
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


