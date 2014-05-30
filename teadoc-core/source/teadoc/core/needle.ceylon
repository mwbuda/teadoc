
import ceylon.language.meta.model { ... }

alias NeedleInjection => Object(InjectRequest) ;
alias PostProcessing => Object(Object, InjectRequest) ;

class InjectRequest(shared String key, TeadocPattern pattern, TeadocContext context) {

}

interface Needle {
	shared formal Object inject(InjectRequest rq) ;
}

class WrapInjection(shared NeedleInjection wrapped) 
satisfies Needle {
	shared actual Object inject(InjectRequest rq) => wrapped(rq) ;
}

class FixedValue(Object v)
satisfies Needle 
{
	shared actual Object inject(InjectRequest rq) => v ;
}

abstract class PostProcessor(Needle wrapped) 
satisfies Needle {
	shared formal Object postProcess(Object bean, InjectRequest rq) ;
	shared actual Object inject(InjectRequest rq) => postProcess(wrapped.inject(rq), rq) ;
}

class NoArgConstructor(Class type)
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

//TODO: setter injection post processing
