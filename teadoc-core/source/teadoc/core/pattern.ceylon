import ceylon.language.meta.model { InvocationException }
import ceylon.collection { HashSet, MutableList, LinkedList }

class TeadocPattern(String raw) {

	
	shared Character wildcard = '*' ;
	shared Character separator = '.' ;
	shared Set<Character> allowedCharacters = HashSet(String('a'..'z') + String('0'..'9') + "_-" ) ; 
	shared Set<Character> specialCharacters = HashSet( {wildcard, separator} ) ;

	Boolean isChar(Character x)(Character c) => c == x ;

	List<LowLevelPattern> parts => raw.split(isChar(separator),true,false).collect( compilePart ) ;
	{Integer*} wildcardIndexes => parts.indexes((LowLevelPattern element) => element.pattern.contains(".*")) ;
	
	Set<Character> illegalCharactersIn(
		String keyPortion, Boolean includeWildcard = false, Boolean includeSep = false
	) {
		variable Set<Character> result = HashSet(keyPortion).complement(allowedCharacters) ;
		if (includeWildcard) { 
			result = HashSet( result.filter(isChar(wildcard)) ) ; 
		} 
		
		if (includeSep) {
			result = HashSet( result.filter(isChar(separator)) ) ;
		}
		
		return result ;
	}

	LowLevelPattern compilePart(String part) {
		String cleanPart = part.normalized.lowercased ;
		
		
		//should be empty of illegal chars, or contain 
		Set<Character> illegalChars = illegalCharactersIn(part,true) ;
		if ( !illegalChars.empty ) {
			throw InvocationException(
				"unsupported characters in pattern part format: ``cleanPart`` <- ``illegalChars``"
			) ;
		}
		
		if (cleanPart.empty) {
			throw InvocationException("cannot compile pattern with blank parts") ;
		}
		
		if (cleanPart.contains("*"), !cleanPart.endsWith("*")) {
			throw InvocationException("unsupported wildcard pattern part format: ``cleanPart``") ;
		}
		
		return LowLevelPattern(cleanPart.replace("*", ".*")) ;
	}

	shared Boolean isAbstract => raw.includes("*") ;
	
	shared actual String string => raw.normalized.lowercased ;
	
	shared Boolean matches(String raw) { 
		String candidate = raw.normalized.lowercased ;
		
		if (!illegalCharactersIn(candidate,false,true).empty) {
			return false ;
		}
		
		{String*} keyParts = candidate.split(isChar(separator),true,false) ;
		
		if ( keyParts.size != parts.size) {
			return false ;
		}
		
		for (key->pattern in zipEntries(keyParts, parts)) {
			if ( !pattern.matches(key) ) {
				return false ;
			}
		}
		
		return true ;
	}

	shared [String*] extractFromKey(String raw) {
		String key = compileKey(raw) ;
		
		if (!isAbstract) {
			return [] ;
		}
		
		{String*} keyParts = key.split(isChar(separator),true,false) ;
		
		variable Integer i = 0 ;
		Integer maxi = max(wildcardIndexes) else 0 ;
		MutableList<String> result = LinkedList<String>() ;
		for (String part in keyParts) {
			if (wildcardIndexes.contains(i)) { result.add(part); }
			i += 1 ;
			if (i >= maxi) { break ; }
		}
		
		return [ *result ] ;
	}

	shared String compileKey(String raw) {
		String candidate = raw.normalized.lowercased ;
		assert( matches(candidate) ) ;
		return candidate ;
	}
	
}

"
 this is a very quick and nasty simple regex like pattern datatype.
 I am introducing it here because at time of coding; Ceylon lacks a standardized implemenation of something like this; 
 at least so far as I can tell (version 1.0.0).
 
 When the language acquires a standard means of doing this kind of generalized text matching; we SHOULD (and hopefully WILL) switch to 
 that instead.
 this is very much intended to only be minimally sufficient

 do not confuse this class with TeadocPattern; the focus of TeadocPattern is to establish highly idosyncratic pattern rules for the purposes
 of defining references in TeadocContext; and related special functionality (primarily resolving abstract patterns to concrete patterns).
 TeadocPattern is dependent upon 'low level' character munging to do it's job, but doesn't want to know the details involved.

 This implemenation is based (loosely) upon the algorithms 1st chapter of 'Beutifal Code' (pub O'Reilly Media Inc; 2007); by Brian Kernigan
 note that it omits the start/end symbols; we are expecting whole string matches here.
"
class LowLevelPattern(shared String pattern) {
	shared actual String string => pattern ;
	Integer psize = pattern.size ;

	"ASCII END OF TEXT character; used as null equiv thru much of this code"
	Character eot = '\{#0003}' ;

	shared Boolean matches(String text) {
		Integer tsize = text.size ;

		variable Integer pi = 0 ;
		variable Integer ti = 0 ;

		while ( pi <= psize, ti <= tsize) {
			String p = pattern[pi...] ;
			String t = text[ti...] ;

			Character cp = p.first else eot ;
			Character ct = t.first else eot ;
			Character np = p.rest.first else eot ;

			Boolean isStar = np == '*' ;
			Boolean isPDone = p.empty ;
			Boolean isTDone = t.empty ;

			if (isPDone, isTDone, !isStar ) {
				return true ;
			}
			
			if (isStar) {
				Integer skipAhead = matchStar(cp,t) ;
				pi += 2 ;
				ti += skipAhead ;
				continue ;
			}
			
			if (!isTDone, compareChars(cp, ct)) {
				pi += 1 ;
				ti += 1 ;
				continue ;
			}
	
			return false ;
		}

		return true ;

	}

	Boolean compareChars(Character pc, Character tc) {
		return pc == tc || pc == '.' ;
	}

	Integer matchStar(Character cp, String t, Integer lc = 0) {
		Character ct = t.first else eot ;
		
		if (compareChars(cp, ct) ) {
			return matchStar(cp,t.rest,lc+1) ;
		}

		else {
			return lc ;
		}
	}

}