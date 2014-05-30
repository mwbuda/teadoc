
import ceylon.language.meta.model { ... }

/*
 top level generic definitions

*/

alias Injection => Object(InjectRequest) ;
alias PostProcessing => Object(Object, InjectRequest) ;

class InjectRequest(shared String key, TeadocPattern pattern, TeadocContext context) {

}

interface Needle {
	shared formal Object inject(InjectRequest rq) ;
	shared Needle with(PostProcessor | PostProcessing pp) => PostProcessed(this,{pp}) ;
}

interface PostProcessor {
	shared formal Object postProcess(Object bean, InjectRequest rq) ;
}

/*
 specific common use implemenations

*/
class DoInjection(shared Injection wrapped) 
satisfies Needle {
	shared actual Object inject(InjectRequest rq) => wrapped(rq) ;
}

class FixedValue(Object v)
satisfies Needle 
{
	shared actual Object inject(InjectRequest rq) => v ;
}

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

class NoArgType(Class type)
satisfies  Needle {
	shared actual Object inject(InjectRequest rq) {
		if ( exists bean = type.apply([]) ) {
			return bean ;
		}
		else {
			throw InitializationException("unable to create new object of type = ``type``") ;
		}
	}
}

//TODO: arguments constructor based needle
//TODO: setter injection post processing
