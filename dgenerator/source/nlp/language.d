// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.nlp.language;

import std.container: Array;
import std.stdio;
import std.conv;
import std.file: readText, FileException;
import dgenerator.utils.helper: NeighborRepresentation;
import dgenerator.nlp.hyphenator: Hyphenator;
import dgenerator.nlp.nlp;
import std.json;
import std.path;
import std.string;
import std.algorithm: canFind;

/**
 * @class
 * PronounTable
 *
 * @brief
 * A simple collection of pronouns and their wrong associations.
 */
class PronounTable {

  /**
   * @brief
   * Constructor.
   *
   * @param [in]sBasePronoun
   * the base pronoun.
   * @param [in]lstWrongPronouns
   * A list of all wrong pronouns for the base form.
   */
  this(dstring sBasePronoun, dstring[] lstWrongPronouns) {
    this.msBasePronoun = sBasePronoun;
    this.mlstWrongPronouns = lstWrongPronouns;
  }

  /**
   * @brief
   * Returns a reference to the base pronoun.
   *
   * @return
   * Reference to base pronoun.
   +/
  ref dstring getBasePronoun() {
    return this.msBasePronoun;
  }

  /**
   * @brief
   * returns the number of wrong pronouns.
   *
   * @return
   * Number of wrong pronouns.
   */
  ulong getNumWrongPronouns() {
    return this.mlstWrongPronouns.length;
  }

  /**
   * @brief
   * Returns a reference to the list of wrong pronouns.
   *
   * @return
   * Reference to list of wrong pronouns.
   */
  ref dstring[] getWrongPronouns() {
    return this.mlstWrongPronouns;
  }

  /**
   * @brief
   * Returns the wrong pronoun at index position nIdx.
   *
   * @return
   * Returns the wrong pronoun at index position nIdx.
   */
  dstring getWrongPronoun(ulong nIdx) {
    return this.mlstWrongPronouns[nIdx];
  }

  /**
   * the base pronoun.
   */
  dstring msBasePronoun;
  /**
   * List of all wrong pronouns.
   */
  dstring[] mlstWrongPronouns;
}

/**
 * @class
 * Language
 *
 * @brief
 * The language.
 */
class Language {

  /**
   * @brief
   * Default constructor. This one will set the data dir to "/data/" and the used language code
   * to "en_US".
   */
  this() {
    this.msDataDir = "/data/";
    this.msLangCode = "en_US";

    // TODO(naetherm): Works for now, because we only support english
    this.mlstContractions=["n't", "'ve", "'d", "'s", "'m", "'re", "'ll", "N'T", "'VE", "'D", "'S", "'M", "'RE", "'LL", "n’t", "’ve", "’d", "’s", "’m", "’re", "’ll", "N’T", "’VE", "’D", "’S", "’M", "’RE", "’LL"];
    this.mlstPersonalPronouns=["i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them"];
    this.mlstSubjPronouns=["i", "you", "he", "she", "it", "we", "they", "what", "who"];
    this.mlstObjPronouns=["me", "him", "her", "it", "us", "you", "them", "whom"];
    this.mlstPossPronouns=["her", "his", "my", "their", "your", "our", "hers", "his", "mine", "theirs", "yours", "ours", "whose"];
    this.mlstDemPronouns=["this", "that", "these", "those"];
    this.mlstCondClause=["if", "when", "then"];
    this.mlstGreetings=["hi", "hey", "hello", "howdy", "sup", "whazzup", "hiya", "yo", "whatup", "greetings"];
    this.mlstToBeForms=["is", "am", "'m", "'s", "be", "was", "were", "those"];
    this.mlstModalVerbs=["can", "could", "may", "might", "shall", "should", "will", "would", "must"];
    this.mlstInterPronouns=["who", "whom", "which", "what", "whose", "whoever", "whatever", "whichever", "whomever"];
    this.mlstTimeRelated=["week", "month", "tomorrow", "yesterday", "today", "weekend", "time", "someday", "evening", "night", "morning", "midnight", "hour", "minute", "day", "second", "then", "before", "after"];
    this.mlstNumerals=["two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty", "twenty-one", "twenty-two", "twenty-three", "twenty-four", "twenty-five", "twenty-six", "twenty-seven", "twenty-eight", "twenty-nine", "thirty", "thirty-one", "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred", "thousand", "many", "multiple", "few", "million"];
    this.mlstIdentifyingPronouns=["anything", "everybody", "another", "each", "few", "many", "none", "some", "all", "any", "anybody", "anyone", "everyone", "everything", "no one", "nobody", "nothing", "none", "other", "others", "several", "somebody", "someone", "something", "most", "enough", "little", "more", "both", "either", "neither", "one", "much", "such"];
    this.mlstConjunctions=["after", "as", "before", "if", "since", "that", "though", "unless", "until", "when", "while"];

    this.readIn();
  }

  /**
   * @brief
   * Constructor.
   *
   * @param [in]sDataDir
   * the data directory to use for reading the language parameters.
   * @param [in]sLangCode
   * The lang code of the language to read in.
   */
  this(string sDataDir, string sLangCode) {
    this.msDataDir = sDataDir;
    this.msLangCode = sLangCode;

    // TODO(naetherm): Works for now, because we only support english
    this.mlstContractions=["n't", "'ve", "'d", "'s", "'m", "'re", "'ll", "N'T", "'VE", "'D", "'S", "'M", "'RE", "'LL", "n’t", "’ve", "’d", "’s", "’m", "’re", "’ll", "N’T", "’VE", "’D", "’S", "’M", "’RE", "’LL"];
    this.mlstPersonalPronouns=["i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them"];
    this.mlstSubjPronouns=["i", "you", "he", "she", "it", "we", "they", "what", "who"];
    this.mlstObjPronouns=["me", "him", "her", "it", "us", "you", "them", "whom"];
    this.mlstPossPronouns=["her", "his", "my", "their", "your", "our", "hers", "his", "mine", "theirs", "yours", "ours", "whose"];
    this.mlstDemPronouns=["this", "that", "these", "those"];
    this.mlstCondClause=["if", "when", "then"];
    this.mlstGreetings=["hi", "hey", "hello", "howdy", "sup", "whazzup", "hiya", "yo", "whatup", "greetings"];
    this.mlstToBeForms=["is", "am", "'m", "'s", "be", "was", "were", "those"];
    this.mlstModalVerbs=["can", "could", "may", "might", "shall", "should", "will", "would", "must"];
    this.mlstInterPronouns=["who", "whom", "which", "what", "whose", "whoever", "whatever", "whichever", "whomever"];
    this.mlstTimeRelated=["week", "month", "tomorrow", "yesterday", "today", "weekend", "time", "someday", "evening", "night", "morning", "midnight", "hour", "minute", "day", "second", "then", "before", "after"];
    this.mlstNumerals=["two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty", "twenty-one", "twenty-two", "twenty-three", "twenty-four", "twenty-five", "twenty-six", "twenty-seven", "twenty-eight", "twenty-nine", "thirty", "thirty-one", "forty", "fifty", "sixty", "seventy", "eighty", "ninety", "hundred", "thousand", "many", "multiple", "few", "million"];
    this.mlstIdentifyingPronouns=["anything", "everybody", "another", "each", "few", "many", "none", "some", "all", "any", "anybody", "anyone", "everyone", "everything", "no one", "nobody", "nothing", "none", "other", "others", "several", "somebody", "someone", "something", "most", "enough", "little", "more", "both", "either", "neither", "one", "much", "such"];
    this.mlstConjunctions=["after", "as", "before", "if", "since", "that", "though", "unless", "until", "when", "while"];

    this.readIn();
  }


  /**
   * @brief
   * Determines if the given word @p sWord is a noun word.
   *
   * @return
   * True if the given word is a noun, false otherwise.
   */
  bool isNoun(dstring sWord) {
    return this.mcNouns.contains(sWord);
  }

  /**
   * @brief
   * Determines if the given word @p sWord is a verb.
   *
   * @return
   * True if the given word is a verb, false otherwise.
   */
  bool isVerb(dstring sWord) {
    return this.mcVerbTable.isVerb(sWord);
  }

  VerbTenses verbTense(dstring sVerb) {
    return this.mcVerbTable.verbTense(sVerb);
  }

  dstring verbGetTense(dstring sVerb, VerbTenses cTense, bool bNegate=false) {
    if ([VerbTenses.FirstSingularPast, VerbTenses.SecondSingularPast, VerbTenses.ThirdSingularPast, VerbTenses.PastPlural].canFind(cTense)) {
      return this.mcVerbTable.verbPast(sVerb, cTense, bNegate);
    }
    else if ([VerbTenses.FirstSingularPresent, VerbTenses.SecondSingularPresent, VerbTenses.ThirdSingularPresent, VerbTenses.Infinitive].canFind(cTense)) {
      return this.mcVerbTable.verbPresent(sVerb, cTense, bNegate);
    }
    else if (cTense == VerbTenses.PresentParticiple) {
      return this.mcVerbTable.verbPresentParticiple(sVerb);
    } else {
      return this.mcVerbTable.conjugate(sVerb, cTense, bNegate);
    }
  }


  bool isKeyInNeighbourhood(dstring sKey) {
    if (sKey in this.mlstKey2N) {
      return true;
    }
    return false;
  }

  bool isIdInNeighbourhood(ulong nIdx) {
    if (nIdx in this.mlstId2N) {
      return true;
    }
    return false;
  }

  bool isContraction(dstring sToken) {
    foreach(c; this.mlstContractions) {
      if (sToken.endsWith(c)) {
        return true;
      }
    }
    return false;
  }

  bool isPersonalPronoun(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstPersonalPronouns.canFind(sToken.toLower());
    }
    return this.mlstPersonalPronouns.canFind(sToken);
  }

  bool isSubjPronoun(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstSubjPronouns.canFind(sToken.toLower());
    }
    return this.mlstSubjPronouns.canFind(sToken);
  }

  bool isObjPronoun(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstObjPronouns.canFind(sToken.toLower());
    }
    return this.mlstObjPronouns.canFind(sToken);
  }

  bool isPossPronoun(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstPossPronouns.canFind(sToken.toLower());
    }
    return this.mlstPossPronouns.canFind(sToken);
  }

  bool isDemPronouns(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstDemPronouns.canFind(sToken.toLower());
    }
    return this.mlstDemPronouns.canFind(sToken);
  }

  bool isCondClause(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstCondClause.canFind(sToken.toLower());
    }
    return this.mlstCondClause.canFind(sToken);
  }

  bool isGreeting(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstGreetings.canFind(sToken.toLower());
    }
    return this.mlstGreetings.canFind(sToken);
  }

  bool isToBeForm(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstToBeForms.canFind(sToken.toLower());
    }
    return this.mlstToBeForms.canFind(sToken);
  }

  bool isModalVerb(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstModalVerbs.canFind(sToken.toLower());
    }
    return this.mlstModalVerbs.canFind(sToken);
  }

  bool isInterPronoun(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstInterPronouns.canFind(sToken.toLower());
    }
    return this.mlstInterPronouns.canFind(sToken);
  }

  bool isTimeRelated(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstTimeRelated.canFind(sToken.toLower());
    }
    return this.mlstTimeRelated.canFind(sToken);
  }

  bool isNumeralWord(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstNumerals.canFind(sToken.toLower());
    }
    return this.mlstNumerals.canFind(sToken);
  }

  bool isIdentifyingPronoun(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstIdentifyingPronouns.canFind(sToken.toLower());
    }
    return this.mlstIdentifyingPronouns.canFind(sToken);
  }

  bool isConjunction(dstring sToken, bool bIgnoreCase=true) {
    if (bIgnoreCase) {
      return this.mlstConjunctions.canFind(sToken.toLower());
    }
    return this.mlstConjunctions.canFind(sToken);
  }

  ref PronounTable getPronounTableByKey(dstring sKey) {
    return this.mlstPronounAssociations[sKey];
  }

  ref NeighborRepresentation getNeighbourhoodById(ulong idx) {
    return this.mlstId2N[idx];
  }

  ref NeighborRepresentation getNeighbourhoodByKey(dstring key) {
    return this.mlstKey2N[key];
  }

  ref PronounTable[dstring] getPronounsTable() {
    return this.mlstPronounAssociations;
  }

  ref NeighborRepresentation[ulong] getIdNeighbourhood() {
    return this.mlstId2N;
  }

  ref NeighborRepresentation[dstring] getKeyNeighbourhood() {
    return this.mlstKey2N;
  }

  ref Hyphenator getHyphenator() {
    return this.mcHyphenator;
  }


  /**
   * @brief
   * Reads the content of every resource associated with the given language code.
   */
  void readIn() {
    // Read the language dictionary
    this.readLanguageDictionary();
    // Read the personal pronoun dictionary
    this.readPersonalPronounDictionary();
    // Read tense dictionary
    this.readTenseDictionary();
    // Read hyphenation dictionary
    this.readHyphenationDictionary();
    // Load noun information
    this.mcNouns = new Dictionary(buildPath(this.msDataDir, "noun"), this.msLangCode, 0, ' ');
    // Load the verb information
    this.mcVerbTable = new VerbTable(buildPath(this.msDataDir, "verb"), this.msLangCode);
  }


  /**
   * @brief
   *
   */
  private void readLanguageDictionary() {
    string[] langDict = null;

    langDict = readText(buildPath(this.msDataDir, "langs", format("%s.bin", this.msLangCode))).split("\n");

    ulong nCounter = 0;

    foreach (string line; langDict) {
      // TODO(naetherm): Read new linewise encoding:
      // NOTE: The line number represents the unique ID (starting with ID=0)
      // WORD#TYPE#[LIST OF REAL WORD IDS]#[LIST OF ARCHAIC WORD IDS]
      auto splitted = line.split("#");
      if (splitted.length >= 2) {
        auto s_word = to!dstring(splitted[0]);
        auto s_type = splitted[1];
        auto s_reals = to!(ulong[])(split(splitted[2]));
        auto s_archaics = to!(ulong[])(split(splitted[3]));
        ulong[] s_errors;
        if (splitted.length > 4) {
          s_errors = to!(ulong[])(split(splitted[4]));
        }
        NeighborRepresentation nRep = new NeighborRepresentation(
          s_word,
          nCounter,
          s_type,
          s_reals,
          s_archaics,
          s_errors);

        this.mlstId2N[nCounter] = nRep;
        this.mlstKey2N[s_word] = nRep;

        ++nCounter;
      }
    }
  }

  /**
   * @brief
   * Read the table containing all personal pronouns and their replacements.
   */
  private void readPersonalPronounDictionary() {
    string[] pPronouns = null;

    // Read the file with the personal pronoun perturbations
    pPronouns = readText(buildPath(this.msDataDir, "personal_pronoun", format("%s.bin", this.msLangCode))).split("\n");

    ulong nCounter = 0;

    // Loop through each line and collect the 'misspelled' versions
    foreach (string line; pPronouns) {
      auto splitted = line.split("#");

      if (splitted.length == 2) {
        // The first word
        auto s_word = to!dstring(splitted[0]);
        // The words, the first one can be replaced by
        auto s_words = to!(dstring[])(split(splitted[1]));

        // Add new entry for the pronoun table
        PronounTable pPronounEntry = new PronounTable(s_word, s_words);

        // Add to pronoun table
        this.mlstPronounAssociations[s_word] = pPronounEntry;
      } else {
        writeln(format("The fetched line does not consist of exactly two parts. Found %d number of parts in line %d.", splitted.length, nCounter));
      }
      ++nCounter;
    }
  }

  /**
   * @brief
   *
   */
  private void readTenseDictionary() {
    // TODO(naetherm): Implement me!
    // TODO(naetherm): How do we handle and generate the tense information offline so that we can use it right here?
  }

  /**
   * @brief
   *
   */
  private void readHyphenationDictionary() {
    // Just call the constructor of the hyphenator, everything else os done within that class
    this.mcHyphenator = new Hyphenator(readText(buildPath(this.msDataDir, "hyphen", format("hyphP_%s.tex", this.msLangCode))));
  }


  /**
   * The base directory of all data.
   */
  string msDataDir;
  /**
   * The language of the current language.
   */
  string msLangCode;

  /**
   * A list of all pronouns and their wrong pronouns.
   */
  private PronounTable[dstring] mlstPronounAssociations;

  /**
   * Dictionary containing information of ~100,000 nouns.
   */
  private Dictionary mcNouns;

  /**
   * Structure containing information about ~10,000 verbs.
   */
  private VerbTable mcVerbTable;

  /**
   * List of Neighborhood representations id->neighborhood
   */
  private NeighborRepresentation[ulong] mlstId2N;

  /**
   * List of Neighborhood representations string->neighborhood
   */
  private NeighborRepresentation[dstring] mlstKey2N;

  /**
   * The hyphenator.
   */
  private Hyphenator mcHyphenator;


  private dstring[] mlstContractions;

  private dstring[] mlstPersonalPronouns;

  private dstring[] mlstSubjPronouns;

  private dstring[] mlstObjPronouns;

  private dstring[] mlstPossPronouns;

  private dstring[] mlstDemPronouns;

  private dstring[] mlstCondClause;

  private dstring[] mlstGreetings;

  private dstring[] mlstToBeForms;

  private dstring[] mlstModalVerbs;

  private dstring[] mlstInterPronouns;

  private dstring[] mlstTimeRelated;

  private dstring[] mlstNumerals;

  private dstring[] mlstIdentifyingPronouns;

  private dstring[] mlstConjunctions;

}
