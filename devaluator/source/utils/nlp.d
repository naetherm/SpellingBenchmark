// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.nlp;

import std.algorithm;
import std.algorithm.mutation;
import std.container;
import std.math;
import std.range;
import std.stdio;
import std.string;
import std.typecons: tuple, Tuple;
import std.path: buildPath;

import std.conv;
import std.file: readText, FileException;

// We need this for the efficient ZeroCutAlignment
import devaluator.utils.queue;
import devaluator.utils.helper: PredictionRepr, GroundtruthRepr, SourceRepr;

double jwSimilarity(
    dstring s, 
    dstring a
)
{
    long i;
    long j;
    long l;
    long m = 0;
    long t = 0;
    long sl = to!long(s.length);
    long al = to!long(a.length);
    auto sflags = new bool[sl];
    auto aflags = new bool[al];
        
    long range = max(0, max(sl, al) / 2 - 1);
    double dw;
    if(!sl || !al)
        return 0;
    for(i = 0; i < al; i++)
        aflags[i] = 0;
    for(i = 0; i < sl; i++)
        sflags[i] = 0;
    /* calculate matching characters */
    
    for(i = 0; i < al; i++)
    {
        for(j = max(i - range, 0), l = min(i + range + 1, sl); j < l; j++)
        {
            if(a[i] == s[j] && !sflags[j])
            {
                sflags[j] = true;
                aflags[i] = true;
                m++;
                break;
            }
            
        }
        
    }
    
    if(!m)
        return 0;
    /* calculate character transpositions */
    
    l = 0;
    for(i = 0; i < al; i++)
    {
        if(aflags[i] == true)
        {
            for(j = l; j < sl; j++)
            {
                if(sflags[j] == true)
                {
                    l = j + 1;
                    break;
                }
                
            }
            
            if(a[i] != s[j])
                t++;
        }
        
    }
    
    t /= 2;
    /* Jaro distance */
    
    dw = ((cast(double)m / cast(double)sl) + (cast(double)m / al) + (cast(double)(m - t) / m)) / 3;
    /* calculate common string prefix up to 4 chars */
    
    l = 0;
    /* Jaro-Winkler distance */
    
    return dw;
}


auto jaroSimilarity(in dstring s1, in dstring s2) {
  int s1_len = cast(int) s1.length;
  int s2_len = cast(int) s2.length;
  if (s1_len == 0 && s2_len == 0) return 1;

  import std.algorithm.comparison: min, max;
  auto match_distance = max(s1_len, s2_len) / 2 - 1;
  auto s1_matches = new bool[s1_len];
  auto s2_matches = new bool[s2_len];
  int matches = 0;
  for (auto i = 0; i < s1_len; i++) {
    auto start = max(0, i - match_distance);
    auto end = min(i + match_distance + 1, s2_len);
    for (auto j = start; j < end; j++)
      if (!s2_matches[j] && s1[i] == s2[j]) {
        s1_matches[i] = true;
        s2_matches[j] = true;
        matches++;
        break;
      }
  }
  if (matches == 0) return 0;

  auto t = 0.0;
  auto k = 0;
  for (auto i = 0; i < s1_len; i++)
    if (s1_matches[i]) {
      while (!s2_matches[k]) k++;
      if (s1[i] != s2[k++]) t += 0.5;
    }
  const double m = matches;
  return (m / s1_len + m / s2_len + (m - t) / m) / 3.0;
}


/**
 * @class
 * NGram
 *
 * @brief
 * Builds an n-gram of the given input array with single token lengths of @p size.
 */
class NGram(TType) {

  /**
   * @brief
   * Constructor.
   *
   * @param [in]input
   * the sequence we want to generate n-grams of.
   * @param [in]size
   * The size of the single grams.
   */
  this(TType[] input, ulong size) {
    this.input = input;
    this.size = min(size, this.input.length);
    if (this.size == 0) {
      this.size = 1;
    }

    this.build();
  }

  ulong numGrams() const {
    return this.grams.length;
  }

  TType[] getGram(ulong idx) {
    return this.grams[idx];
  }


  void build() {
    for (int i = 0; i <= this.input.length - size; i++) {
      TType[] gram;
      for (int j = 0; j < this.size; j++) {
        gram ~= this.input[i+j];
      }
      this.grams.insertBack(gram.dup);
    }
  }

  ref Array!(TType[]) getGrams() {
    return this.grams;
  }

  /**
   *
   */
  TType[] input;

  /**
   *
   */
  Array!(TType[]) grams;

  /**
   *
   */
  ulong size;
}


unittest {
  int[] comparer = [1, 2, 3, 4, 5];
  auto ngram = new NGram!int([1, 2, 3, 4, 5], 2);

  assert(ngram.numGrams() == 4);
  assert(ngram.getGram(0) == comparer[0..2]);
  assert(ngram.getGram(1) == comparer[1..3]);
  assert(ngram.getGram(2) == comparer[2..4]);
  assert(ngram.getGram(3) == comparer[3..5]);
}

unittest {

  import std.string;

  dstring[] comparer = ["a", "b", "c", "d", "e"];
  auto ngram = new NGram!dstring(["a", "b", "c", "d", "e"], 2);

  assert(ngram.numGrams() == 4);
  assert(ngram.getGram(0) == comparer[0..2]);
  assert(ngram.getGram(1) == comparer[1..3]);
  assert(ngram.getGram(2) == comparer[2..4]);
  assert(ngram.getGram(3) == comparer[3..5]);
}

unittest {

  import std.string;

  dstring[] comparer = ["a", "b", "c", "d", "e"];
  auto ngram = new NGram!dstring(["a", "b", "c", "d", "e"], 3);

  assert(ngram.numGrams() == 3);
  assert(ngram.getGram(0) == comparer[0..3]);
  assert(ngram.getGram(1) == comparer[1..4]);
  assert(ngram.getGram(2) == comparer[2..5]);
}

unittest {

  import std.string;

  dchar[] comparer = ['a', 'b', 'c', 'd', 'e'];
  auto ngram = new NGram!dchar(['a', 'b', 'c', 'd', 'e'], 0);

  assert(ngram.numGrams() == 5);
  assert(ngram.getGram(0) == comparer[0..1]);
  assert(ngram.getGram(1) == comparer[1..2]);
  assert(ngram.getGram(2) == comparer[2..3]);
  assert(ngram.getGram(3) == comparer[3..4]);
  assert(ngram.getGram(4) == comparer[4..$]);
}

unittest {

  import std.string;

  dstring[] comparer = ["a", "b", "c", "d", "e"];
  auto ngram = new NGram!dstring(["a", "b", "c", "d", "e"], 42);

  assert(ngram.numGrams() == 1);
  assert(ngram.getGram(0) == comparer[0..$]);
}


unittest {

  import std.string;

  dstring[] comparer = ["abc", "bcd", "cde", "def", "e"];
  auto ngram = new NGram!dstring(["abc", "bcd", "cde", "def", "e"], 3);

  assert(ngram.numGrams() == 3);
  assert(ngram.getGram(0) == comparer[0..3]);
  assert(ngram.getGram(1) == comparer[1..4]);
  assert(ngram.getGram(2) == comparer[2..5]);
}


/**
 * @class
 * NGramMatcher
 *
 * @brief
 * Builds the alignment set for the two given n-grams.
 *
 * DEPRECATED?
 */
class NGramMatcher(TType) {

  this(NGram!TType first, NGram!TType second) {
    this.first = first;
    this.second = second;

    this.build();
  }

  this(ref TType[] first, ref TType[] second, ulong n) {
    this.first = new NGram!TType(first, n);
    this.second = new NGram!TType(second, n);

    this.build();
  }

  ulong[ulong] getAlignment() {
    return this.alignment;
  }

  void build() {
    foreach (ulong fidx, f; this.first) {
      foreach (ulong sidx, s; this.second) {
        if (equal(f, s)) {

        }
      }
    }
  }

  NGram!TType first;
  NGram!TType second;

  ulong[ulong] alignment;
}


////////////////////////////////////////////////////////////////////////////////
// Unit Tests
////////////////////////////////////////////////////////////////////////////////
/*
unittest {
  import devaluator.utils.nlp;

  dstring[] first = ["And", "another", "test", "sentence", "."];
  dstring[] second = ["And", "another", "test", "sentence", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);
  zca.build();

  assert(zca.alignedGroups.length == 5);

  assert(zca.alignedGroups[0][0] == zca.alignedGroups[0][1] && zca.alignedGroups[0][0] == 0);
  assert(zca.alignedGroups[1][0] == zca.alignedGroups[1][1] && zca.alignedGroups[1][0] == 1);
  assert(zca.alignedGroups[2][0] == zca.alignedGroups[2][1] && zca.alignedGroups[2][0] == 2);
  assert(zca.alignedGroups[3][0] == zca.alignedGroups[3][1] && zca.alignedGroups[3][0] == 3);
  assert(zca.alignedGroups[4][0] == zca.alignedGroups[4][1] && zca.alignedGroups[4][0] == 4);
  assert(zca.gapGroups.empty);
}

unittest {
  import devaluator.utils.nlp;

  dstring[] first = ["And", "another", "text", "sentence", "."];
  dstring[] second = ["And", "another", "test", "sentence", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);
  zca.build();

  assert(zca.alignedGroups.length == 4);

  assert(zca.alignedGroups[0][0] == zca.alignedGroups[0][1] && zca.alignedGroups[0][0] == 0);
  assert(zca.alignedGroups[1][0] == zca.alignedGroups[1][1] && zca.alignedGroups[1][0] == 1);
  assert(zca.alignedGroups[2][0] == zca.alignedGroups[2][1] && zca.alignedGroups[2][0] == 3);
  assert(zca.alignedGroups[3][0] == zca.alignedGroups[3][1] && zca.alignedGroups[3][0] == 4);

  assert(zca.gapGroups.length == 1);
  assert(zca.gapGroups[0][0] == 2);
  assert(zca.gapGroups[0][1] == 2);
}

unittest {
  import devaluator.utils.nlp;

  dstring[] first = ["And", "another", "text", "test", "sentence", "."];
  dstring[] second = ["And", "another", "test", "test", "sentence", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);
  zca.build();

  assert(zca.alignedGroups.length == 5);

  assert(zca.alignedGroups[0][0] == zca.alignedGroups[0][1] && zca.alignedGroups[0][0] == 3);
  assert(zca.alignedGroups[1][0] == zca.alignedGroups[1][1] && zca.alignedGroups[1][0] == 4);
  assert(zca.alignedGroups[2][0] == zca.alignedGroups[2][1] && zca.alignedGroups[2][0] == 5);
  assert(zca.alignedGroups[3][0] == zca.alignedGroups[3][1] && zca.alignedGroups[3][0] == 0);
  assert(zca.alignedGroups[4][0] == zca.alignedGroups[4][1] && zca.alignedGroups[4][0] == 1);

  assert(zca.gapGroups.length == 1);
  assert(zca.gapGroups[0][0] == 2);
  assert(zca.gapGroups[0][1] == 2);
}

unittest {
  import devaluator.utils.nlp;

  dstring[] first = ["And", "another", "test", "sentence", "."];
  dstring[] second = ["And", "another", "test", "test", "sentence", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);
  zca.build();

  assert(zca.alignedGroups.length == 5);

  assert(zca.alignedGroups[0][0] == zca.alignedGroups[0][1] && zca.alignedGroups[0][0] == 0);
  assert(zca.alignedGroups[1][0] == zca.alignedGroups[1][1] && zca.alignedGroups[1][0] == 1);
  assert(zca.alignedGroups[2][0] == zca.alignedGroups[2][1] && zca.alignedGroups[2][0] == 2);
  assert(zca.alignedGroups[3][0] == 3 && zca.alignedGroups[3][1] == 4);
  assert(zca.alignedGroups[4][0] == 4 && zca.alignedGroups[4][1] == 5);

  assert(zca.gapGroups.length == 1);
  assert(zca.gapGroups[0][0] == -1);
  assert(zca.gapGroups[0][1] == 3);
}
unittest {
  import devaluator.utils.nlp;

  dstring[] first = ["And", "another", "test", "aetschi", "sentence", "."];
  dstring[] second = ["And", "another", "test", "sentence", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);
  zca.build();

  assert(zca.alignedGroups.length == 5);

  assert(zca.alignedGroups[0][0] == 0 && zca.alignedGroups[0][1] == 0);
  assert(zca.alignedGroups[1][0] == 1 && zca.alignedGroups[1][1] == 1);
  assert(zca.alignedGroups[2][0] == 2 && zca.alignedGroups[2][1] == 2);
  assert(zca.alignedGroups[3][0] == 4 && zca.alignedGroups[3][1] == 3);
  assert(zca.alignedGroups[4][0] == 5 && zca.alignedGroups[4][1] == 4);

  assert(zca.gapGroups.length == 1);
  assert(zca.gapGroups[0][0] == 3);
  assert(zca.gapGroups[0][1] == -1);
}
*/



/**
 * @class
 * Dictionary
 *
 * @brief
 * Very basic dictionary that can represent any list of types.
 */
class Dictionary {

  this(string sDataDir, string sLangCode, int nColumnOfInterest, char cDelimiter) {
    this.msDataDir = sDataDir;
    this.msLangCode = sLangCode;
    this.mcDelimiter = cDelimiter;
    this.mnColumnOfInterest = nColumnOfInterest;

    // Read all important information
    this.readIn();
  }

  private void readIn() {
    string[] readData = readText(buildPath(this.msDataDir, format("%s.bin", this.msLangCode))).split("\n");

    foreach(line; readData) {
      this.msData ~= to!dstring(line.split(this.mcDelimiter)[this.mnColumnOfInterest]);
    }
  }

  /**
   * @brief
   * Determines and returns whether a given word @p sWord is within this dictionary.
   *
   * @return
   * True if the given word can be found within this dictionary, false otherwise.
   */
  public bool contains(dstring sWord) {
    return this.msData.canFind(sWord);
  }

  private dstring[] msData;

  private string msDataDir;
  private string msLangCode;
  private char mcDelimiter;
  private int mnColumnOfInterest;
}


/**
 * @enum
 * Verbtenses
 *
 * @brief
 */
enum VerbTenses {
  Infinitive = 0,
  FirstSingularPresent,
  SecondSingularPresent,
  ThirdSingularPresent,
  PresentPlural,
  PresentParticiple,
  FirstSingularPast,
  SecondSingularPast,
  ThirdSingularPast,
  PastPlural,
  Past,
  PastParticiple
}


/**
 * @class
 * VerbTable
 *
 * @brief
 */
class VerbTable {

  /**
   * @brief
   * Default constructor.
   */
  this(string sDataDir, string sLangCode) {
    this.msDataDir = sDataDir;
    this.msLangCode = sLangCode;

    // Read in the verb forms
    this.readIn();
  }

  /**
   * @brief
   * Basic check whether the given word @p sWord is a verb.
   *
   * @return
   * True if the given word is a known verb, false otherwise.
   */
  public bool isVerb(dstring sWord) {
    return ((sWord in this.mlstVerbLemmas) !is null);
  }

  /**
   * @brief
   * Returns the infinitive form of a verb, if it's known.
   *
   * @return
   * The infinitive form of a verb.
   */
  public dstring getInfinitive(dstring sWord) {
    if (sWord in this.mlstVerbLemmas) {
      return this.mlstVerbLemmas[sWord];
    }

    return "";
  }

  /**
   * @brief
   * This method will conjugate a given verb @p sWord to the verb tense @p cTense. One can further 
   * define whether the negated form should be returned, if there is any negated form available.
   * If now negation is available an empty string will be returned.
   *
   * @return
   * The conjugated form of the word @p sWord.
   */
  public dstring conjugate(dstring sWord, VerbTenses cTense, bool bNegate=false) {
    // First get the infinitive form
    auto infForm = this.getInfinitive(sWord);

    int nElementIdx = to!int(cTense);
    int nFinalIdx = nElementIdx;

    // The negated forms are appended at the end!
    if (bNegate) {
      nFinalIdx += to!int(VerbTenses.max);
    }

    if (this.mlstVerbTenses[infForm][nFinalIdx] != "") {
      return this.mlstVerbTenses[infForm][nFinalIdx];
    } else {
      return this.mlstVerbTenses[infForm][nElementIdx];
    }
  }

  public VerbTenses verbTense(dstring sWord) {
    // First get the "lemma"
    auto lemma = this.mlstVerbLemmas[sWord];

    for(size_t i = 0; i < this.mlstVerbTenses[lemma].length; ++i) {
      if (this.mlstVerbTenses[lemma][i] == sWord) {
        return to!VerbTenses(i);
      }
    }

    return VerbTenses.Infinitive;
  }

  public dstring verbPresent(dstring sWord, VerbTenses cTense, bool bNegate=false) {
    auto sPresent = this.conjugate(sWord, cTense, bNegate);
    if (sPresent != "") {
      return sPresent;
    }

    return this.conjugate(sWord, VerbTenses.Infinitive, bNegate);
  }

  public dstring verbPast(dstring sWord, VerbTenses cTense, bool bNegate=false) {

    auto sPast = this.conjugate(sWord, cTense, bNegate);
    if (sPast != "") {
      return sPast;
    }

    return this.conjugate(sWord, VerbTenses.Past, bNegate);
  }

  public dstring verbPresentParticiple(dstring sWord) {
    return this.conjugate(sWord, VerbTenses.PresentParticiple);
  }

  public dstring getRandomTense(dstring sVerb) {
    auto currentTense = this.verbTense(sVerb);

    VerbTenses cTense = VerbTenses.Infinitive;

    return this.mlstVerbTenses[this.mlstVerbLemmas[sVerb]][to!int(cTense)];
  }

  /**
   * @brief
   * Reads the verb list and builds the conjugation and lemma table for all found verbs.
   */
  private void readIn() {
    ///
    /// The structure of each line of the file is:
    ///
    ///
    string[] verbs = readText(buildPath(to!string(this.msDataDir), format("%s.bin", this.msLangCode))).split("\n");

    // Now loop through all verbs (obviously not all verbs but the most ~10,000 common verbs)
    foreach(line; verbs) {
      string[] conjugations = line.split(',');

      auto baseForm = to!dstring(conjugations[0]);

      // Add verb to mlstVerbTenses
      this.mlstVerbTenses[baseForm] = to!(dstring[])(conjugations);

      // Create lemmas entries
      foreach(lemma; conjugations) {
        this.mlstVerbLemmas[to!dstring(lemma)] = baseForm;
      }
    }
  }

  /**
   * The data directory of the files.
   */
  private string msDataDir;

  /**
   * The language code of the language code to use.
   */
  private string msLangCode;

  /**
   * List of verb tenses
   */
  private dstring[][dstring] mlstVerbTenses;

  /**
   * List of verb lemmas
   */
  private dstring[dstring] mlstVerbLemmas;
}