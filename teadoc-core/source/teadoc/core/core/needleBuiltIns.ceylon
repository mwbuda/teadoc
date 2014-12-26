import ceylon.language.meta.model { ... }

/*
 specific common use implemenations
 
 */
class DoInjection(shared Injection wrapped) 
satisfies Needle {
	shared actual Object inject(InjectRequest rq) => wrapped(rq) ;
}

class FixedValue(Object v)
satisfies Needle {
	shared actual Object inject(InjectRequest rq) => v ;
}

class ErrorInjection()
satisfies Needle {
	shared actual Object inject(InjectRequest rq) {
		throw InvocationException("erroroneous needle cannot be injected") ;
	}
}

class NoArgType(Class type)
satisfies Needle {
	shared actual Object inject(InjectRequest rq) {
		if ( exists bean = type.apply([]) ) {
			return bean ;
		}
		else {
			throw InitializationException("unable to create new object of type = ``type``") ;
		}
	}
}

abstract class BaseSetterInjection<BT,VT>(
	shared Class<BT> beanType, shared Class<VT> valueType, shared String propertyName
) satisfies PostProcessor {
	shared String methodName = "set``propertyName.span(0,1).uppercased````propertyName.rest``" ;
	
	BT toBeanType(Object bean) {
		if (is BT bean) {
			return bean ;
		}
		else {
			throw InitializationException("provided object ``bean`` is not of class ``beanType``") ;
		}
	}
	
	shared formal VT derivePropertyValue(InjectRequest rq) ;
	
	shared actual Object postProcess(Object bean, InjectRequest rq) {
		BT trueBean = toBeanType(bean) ;
		VT propertyValue = derivePropertyValue(rq) ;
		Method<BT,Anything,[VT]>? setterMethod = beanType.getDeclaredMethod<BT,Anything,[VT]>(methodName) ;
		
		if (exists setterMethod) {
			Function<Anything,[VT]> binding = setterMethod(trueBean) ;
			binding(propertyValue) ;
			return bean ;
		}
		
		else {
			throw InitializationException("can't find indicated method ``methodName`` of class ``beanType``") ;
		}
	}
}

class SetToValue<BT,VT>(Class<BT> beanType, Class<VT> valueType, String property, shared VT val)
extends BaseSetterInjection<BT, VT>(beanType,valueType,property) {
	shared actual VT derivePropertyValue(InjectRequest rq) => val ;
}

//class SetToReference<BT,VT>(Class<BT> beanType, Class<VT> valueType, String property, shared String reference)
//extends BaseSetterInjection<BT, VT>(beanType, valueType, property) {
//	shared actual VT derivePropertyValue(InjectRequest rq) {
//		Object? resref = rq.context.resolve(reference) ;
//		if (exists resref) {
//			if (is VT resref) {
//				return resref ;
//			}
//			else {
//				throw InitializationException("indicated reference ``ref``` not of class ``valueType``") ;
//			}
//		}
//		else {
//			throw InitializationException("can't find indicated reference ``ref```") ;
//		}
//	}
//}

class SetToNeedle<BT,VT>(Class<BT> beanType, Class<VT> valueType, String property, shared Needle needle)
extends BaseSetterInjection<BT, VT>(beanType, valueType, property) {
	
	shared actual VT derivePropertyValue(InjectRequest rq) {
		Object needleValue = needle.inject(rq) ;
		if (is VT needleValue) {
			return needleValue ;
		}
		else {
			throw InitializationException("injected setter value not of class ``valueType``") ;
		}
	}
}

//TODO: arguments constructor based needle
