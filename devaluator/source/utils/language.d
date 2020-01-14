// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.language;

import std.container: Array;
import std.stdio;
import std.conv;
import std.file: readText, FileException;
import std.json;
import std.path;
import std.string;
import std.path: buildPath;
import devaluator.utils.nlp;

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
 * NeighborRepresentation
 *
 * @brief
 */
class NeighborRepresentation {
  /**
   * @brief
   * Constructor.
   */
  this(dstring key, ulong id, string eType, ulong[] reals, ulong[] archaics) {
    this.key = key;
    this.id = id;
    this.eType = eType;
    this.reals = reals;
    this.archaics = archaics;
  }

  /**
   * The key for the neighborhood representation.
   */
  dstring key;
  /**
   * The unique ID.
   */
  ulong id;
  /**
   * The category. This is either REAL_WORD or ARCHAIC.
   */
  string eType;
  /**
   * List containing the unique IDs of all neighbours.
   */
  ulong[] reals;
  /**
   * List containing the unique IDs of all archaics.
   */
  ulong[] archaics;
}

/**
 * @class
 * language
 *
 * @brief
 */
class Language {
  /**
   * @brief
   * Default constructor.
   */
  this() {

  }

  /**
   * @brief
   * Constructor.
   */
  this(string dataDir, string langCode) {
    this.dataDir = dataDir;
    this.langCode = langCode;

    this.readIn();
  }

  /**
   * @brief
   * Reads the content of the given language dictionary.
   */
  void readIn() {
    // First read the language dictionary
    this.readLanguageDictionary();
    // Second read the personal pronoun table
    this.readPersonalPronounDictionary();
    // Load noun information
    this.mcNouns = new Dictionary(buildPath(this.dataDir, "noun"), this.langCode, 0, ' ');
    // Load the verb information
    this.mcVerbTable = new VerbTable(buildPath(this.dataDir, "verb"), this.langCode);
  }


  /**
   * @brief
   * 
   */
  private void readLanguageDictionary() {
    string[] langDict = null;
    
    langDict = readText(buildPath(this.dataDir, "langs", format("%s.bin", this.langCode))).split("\n");
    
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
        NeighborRepresentation nRep = new NeighborRepresentation(s_word, nCounter, s_type, s_reals, s_archaics);

        this.mId2N[nCounter] = nRep;
        this.mKey2N[s_word] = nRep;

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
    pPronouns = readText(buildPath(this.dataDir, "personal_pronoun", format("%s.bin", this.langCode))).split("\n");

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

  ref PronounTable getPronounTableByKey(dstring sKey) {
    return this.mlstPronounAssociations[sKey];
  }

  ref NeighborRepresentation getNeighbourhoodById(ulong idx) {
    return this.mId2N[idx];
  }

  ref NeighborRepresentation getNeighbourhoodByKey(dstring key) {
    return this.mKey2N[key];
  }

  ref PronounTable[dstring] getPronounsTable() {
    return this.mlstPronounAssociations;
  }

  /**
   * @brief
   * Determines if the given word is of type REAL_WORD.
   */
  bool isRealWord(ref dstring word) {
    if (word in this.mKey2N) {
      return this.mKey2N[word].eType == "REAL_WORD";
    }

    return false;
  }

  /**
   * @brief
   * Determines if the given word is of type ARCHAIC.
   */
  bool isArchaicWord(ref dstring word) {
    if (word in this.mKey2N) {
      return this.mKey2N[word].eType == "ARCHAIC";
    }

    return false;
  }

  /**
   * Directory to the data.
   */
  string dataDir;
  /**
   * The language code of this language.
   */
  string langCode;

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

  private NeighborRepresentation[ulong] mId2N;
  private NeighborRepresentation[dstring] mKey2N;
}
