
import ceylon.collection {
	MutableSet, HashSet 
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
	shared Character wildcard = '.' ;
	shared Character zeroOrMore = '*' ;
	shared Character oneOrMore = '+' ;
	shared Character charClassStart = '[' ;
	shared Character charClassEnd = ']' ;
	shared Character charClassRange = '-' ;
	
	shared actual String string => pattern ;

	"ASCII END OF TEXT character; used as null equiv thru much of this code"
	Character eot = '\{#0003}' ;

	Integer psize = pattern.size ;

	shared Boolean match(String text) {
		Integer tsize = text.size ;
		
		variable Integer pi = 0 ;
		variable Integer ti = 0 ;
		
		MutableSet<Character> matchChars = HashSet<Character>();
		variable Integer matchMin = 1 ;
		variable Integer matchMax = 1 ;

		variable String machineState = "scan1" ;

		while ( pi <= psize, ti <= tsize) { 
		String p = pattern[pi...] ;
		String t = text[ti...] ;
		switch (machineState)
			
			//start scanning mode
			case ("scan1") {
				matchChars.clear();
				matchMin = 1 ; matchMax = 1 ;
				Character pc = p.first else eot ;
					
				if (pc == zeroOrMore || pc == oneOrMore ) {
					throw Exception("unexpected sequence indication") ;
				}

				if ( pc == charClassStart) {
					machineState = "scanCC" ;
					continue ;
				}

				pi++ ;
				matchChars.add(pc) ;
				machineState = "scan2" ;
			}

			//follow up scan mode, see if we are in repeating sequence
			case ("scan2") {
				Character pc = p.first else eot  ;
				
				if ( pc == zeroOrMore) {
					pi++ ;
					matchMax = -1 ;
					matchMin = 0 ;
				}

				if ( pc == oneOrMore) {
					pi++ ;
					matchMax = -1 ;
					matchMin = 0 ;
				}

				machineState = "match" ;
			}

			//character class builder scan mode
			case ("scanCC") {
				Character first = p.sequence[pi+1] else eot ;
				Character second = p.sequence[pi+3] else eot ;
				matchChars.addAll(first..second) ;
				pi += 5 ;
				machineState = "scan2" ;
			}

			//after scanning the pattern to a stopping point, match against text
			case ("match") {
				[Boolean,Integer] matchdata = doMatchInternal(matchChars, matchMax, matchMin, t) ;
				if (!matchdata[0]) {
					return false ;
				}
				ti += matchdata[1] ;
				machineState = "scan1" ;
			}

			else {
				throw Exception("unexpected machine state") ;
			}
		}

		return true ;

	}

	[Boolean,Integer] doMatchInternal({Character*} matchSet, Integer max, Integer min, String text) {
		Boolean isWildcard = matchSet.contains(wildcard) ;

		variable Integer count = 0 ;
		for (tc in text) {
			if (tc == eot) { return [count >= min, count] ; }
			Boolean test = isWildcard then true else matchSet.contains(tc) ;
			if (!test) { return [false,count] ; }
			count++ ;
			if (count == max) { return [true,count] ; }
		}

		return [count >= min, count] ;
	}

}

