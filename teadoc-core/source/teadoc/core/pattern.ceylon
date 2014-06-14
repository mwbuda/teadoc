import ceylon.language.meta.model { InvocationException }
import ceylon.collection { HashSet, LinkedList }

alias KeyType => TeadocKey|String ;
alias PatternType => String|TeadocKey|TeadocPattern  ;

Boolean isChar(Character x)(Character? c) {
	if (is Character c) {
		return c == x ;
	}
	return false ;
}

object patternSchema {
	
	shared Character wildcard = '*' ;
	shared Character separator = '.' ;
	shared Character charClassStart = '[' ;
	shared Character charClassEnd = ']' ;
	shared Character charClassRange = '-' ;
	
	shared Set<Character> allowedCharacters = HashSet(String('a'..'z') + String('0'..'9') + "_" ) ; 
	shared Set<Character> specialCharacters = HashSet( {wildcard, separator, charClassStart,charClassEnd} ) ;
	
	shared Integer maxPatternSegments = 255;
	
	shared Set<Character> illegalCharactersIn(
		String keyPortion, 
		Boolean includeWildcard = false, Boolean includeSep = false, Boolean excludeCharClass = false
	) {
		variable Set<Character> result = HashSet(keyPortion).complement(patternSchema.allowedCharacters) ;
		
		if (excludeCharClass) {
			result = HashSet( result.filter(isChar(patternSchema.charClassStart)) ) ;
			result = HashSet( result.filter(isChar(patternSchema.charClassRange)) ) ;
			result = HashSet( result.filter(isChar(patternSchema.charClassEnd)) ) ;
		}
		
		if (includeWildcard) { 
			result = HashSet( result.filter(isChar(patternSchema.wildcard)) ) ; 
		} 
		
		if (includeSep) {
			result = HashSet( result.filter(isChar(patternSchema.separator)) ) ;
		}
		
		return result ;
	}
	
	shared TeadocPattern compilePattern(PatternType raw) {
		switch (raw)
		case (is TeadocPattern) { 
			return raw ;
		}
		else {
			return TeadocPattern(raw) ;
		}
	}
	
	shared TeadocKey compileKey(KeyType raw) {
		switch (raw)
		case (is TeadocKey) { 
			return raw ;
		}
		else {
			return TeadocKey(raw) ;
		}
	}
	
	shared [TeadocPattern*] elligiblePatterns(KeyType key, {PatternType*} patterns) => sort(patterns.collect(compilePattern).filter( 
		(TeadocPattern p) => TeadocPattern(p).match(compileKey(key)) 
	)) ;
}

class TeadocKey(KeyType input) 
satisfies Comparable<TeadocKey> & Identifiable {
	
	String resolveInputToRaw(KeyType i) {
		switch (i)
		case (is TeadocKey) { 
			return i.string ;
		}
		case (is String) {
			return i ;
		}
	}
	
	String raw = resolveInputToRaw(input) ;
	
	shared List<String> parts => raw.split(isChar(patternSchema.separator),true,false).collect( compilePart ) ;
	
	String compilePart(String part) {
		String cleanPart = part.normalized.lowercased ;
		
		//should be empty of illegal chars, or contain 
		Set<Character> illegalChars = patternSchema.illegalCharactersIn(part,false,true,false);
		if ( !illegalChars.empty ) {
			throw InvocationException(
				"unsupported characters in key part format: ``cleanPart`` <- ``illegalChars``"
			) ;
		}
		
		return cleanPart ;
	}
	
	shared actual Boolean equals(Object that) => this.string == that.string.normalized.lowercased ;
	
	shared actual Comparison compare(TeadocKey that) {
		//if of unequal size, larger group pattern matches after shorter
		Comparison cmpSize = this.parts.size <=> that.parts.size ;
		if ( cmpSize != equal) { return cmpSize ; }
		
		//finally, just do a string compare
		return this.string <=> that.string ;
	}

}

class TeadocPattern(PatternType input) 
satisfies Comparable<TeadocPattern> & Identifiable {
	
//
//object construction
//
	String resolveInputToRaw(PatternType i) {
		switch (i)
		case (is TeadocKey|TeadocPattern) { 
			return i.string ;
		}
		case (is String) {
			return i ;
		}
	}
	
	String raw = resolveInputToRaw(input) ;
	shared List<String> parts => LinkedList(raw.normalized.lowercased.split(isChar(patternSchema.separator),true,false)) ;
	List<LowLevelPattern> pparts => parts.collect( compilePart ) ;
	{Integer*} wildcardIndexes => parts.indexes((String part) => part.containsAny(".*[]+") ) ;
	
	//NB: a lot of accomodations here b/c no real underlying regex functionality
	//	when we remove the kludgy quick-&-dirty low level patterns, we can remove a lot of the restrictions here too
	//	(buda)
	LowLevelPattern compilePart(String part) {
		String cleanPart = part.normalized.lowercased ;
		
		//should be empty of illegal chars, or contain wildcards
		Set<Character> illegalChars = patternSchema.illegalCharactersIn(part,true,false,true);
		if ( !illegalChars.empty ) {
			throw InvocationException(
				"unsupported characters in pattern part format: ``cleanPart`` <- ``illegalChars``"
			) ;
		}
		
		if (cleanPart.empty) {
			throw InvocationException("cannot compile pattern with blank parts") ;
		}
		
		if (cleanPart.contains(patternSchema.wildcard), cleanPart != patternSchema.wildcard) {
			throw InvocationException("unsupported wildcard pattern part format: ``cleanPart``") ;
		}
		
		if (cleanPart.contains(patternSchema.charClassStart) || cleanPart.contains(patternSchema.charClassEnd)) {
			Boolean tests = Array<Boolean>([
			cleanPart.size == 5,
			cleanPart.startsWith(patternSchema.charClassStart.string),
			isChar(patternSchema.charClassRange)(cleanPart.sequence[2]),
			cleanPart.endsWith(patternSchema.charClassEnd.string)
			]).fold(true, (Boolean a, Boolean b) => a && b ) ;
			
			if (!tests) {
				throw InvocationException("unsupported character-class pattern part format: ``cleanPart``") ;
			}
		}
		
		return LowLevelPattern(cleanPart.replace(patternSchema.wildcard.string, ".*")) ;
	}

	shared TeadocPattern append(PatternType? other) {
		if (exists other) {
			return TeadocPattern( patternSchema.separator.string.join({this.string, other.string})) ;
		}
		return this ;
	}
	
	shared TeadocPattern prepend(PatternType? other) {
		if (exists other) {
			return TeadocPattern( patternSchema.separator.string.join({other.string, this.string})) ;
		}
		return this ;
	}

//
//properties
//
	shared Boolean isAbstract => raw.includes(patternSchema.wildcard.string) || raw.includes(patternSchema.charClassStart.string) ;
	
	shared actual String string => raw.normalized.lowercased ;

//
// behavior
//	
	
	shared Boolean match(KeyType raw) { 
		TeadocKey candidate ;
		
		try {
			candidate = patternSchema.compileKey(raw) ;
		}
		catch (Exception e) {
			return false ;
		}
		
		{String*} keyParts = candidate.parts ;
		
		if ( keyParts.size != parts.size) {
			return false ;
		}
		
		{Boolean*} matches = {for (key->pattern in zipEntries(keyParts, pparts)) pattern.match(key)} ;
		return !matches.contains(false) ;
	}
	
	shared [String*] extractFromKey(KeyType raw) {
		TeadocKey key = patternSchema.compileKey(raw) ;
		assert( match(key) ) ;
		return isAbstract then [ for (i in wildcardIndexes) key.parts.get(i) else "" ] else [] ;
	}
	
	shared actual Boolean equals(Object that) => this.string == that.string.normalized.lowercased ;
	
	shared actual Comparison compare(TeadocPattern that) {
		//if of unequal size, larger group pattern matches after shorter
		Comparison cmpSize = this.parts.size <=> that.parts.size ;
		if ( cmpSize != equal) { return cmpSize ; }
		
		//otherwie, we compare wildcard index to wilcard index in order, 
		//	patterns with lower wildcard indexes match LATER
		//	EG. a.*.c matches after a.b.*
		[Integer?*] thsWcs = (this.wildcardIndexes.size < that.wildcardIndexes.size) 
			then concatenate(this.wildcardIndexes, [null].repeat(that.wildcardIndexes.size - this.wildcardIndexes.size ) ).sequence 
			else this.wildcardIndexes.sequence 
		;
		
		[Integer?*] thtWcs = (that.wildcardIndexes.size < this.wildcardIndexes.size) 
			then concatenate(that.wildcardIndexes, [null].repeat(this.wildcardIndexes.size - that.wildcardIndexes.size ) ).sequence 
			else that.wildcardIndexes.sequence 
		;
		
		{[Integer?,Integer?]*} pairs = zipPairs(thsWcs, thtWcs) ;
		
		for (pair in pairs) {
			Integer thsWc = pair[0] else patternSchema.maxPatternSegments + 1 ;
			Integer thtWc = pair[1] else patternSchema.maxPatternSegments + 1 ;
			
			switch (thsWc <=> thtWc) 
			case (larger) {
				return smaller ;
			}
			case (smaller) {
				return larger ;
			}
			case (equal) {
				continue ;
			}
				
		}
		
		//finally, just do a string compare
		return this.string <=> that.string ;
	}

}

