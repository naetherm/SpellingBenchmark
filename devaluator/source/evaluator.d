// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.evaluator;

import devaluator.alignment.alignment_linker;
import devaluator.utils.language: Language;
import devaluator.utils.results;
import devaluator.utils.helper: PredictionRepr, GroundtruthRepr, RawRepr, SourceRepr;
import devaluator.utils.data_reader: DataReader, Result;

import std.stdio;
import std.conv;
import std.typecons: tuple, Tuple;
import std.container;
import std.string;
import std.variant;
import std.file;
import vibe.d;

/**
 * @class
 * Evaluator
 *
 * @brief
 * TODO(naetherm): Write me!
 */
class Evaluator {
  /**
   * @brief
   * Constructor.
   */
  this() {
    writeln("Starting Evaluator instance!");

    writeln("Initializing all data readers");
    this.dataReader = new DataReader();
    writeln("\ndone.");
  }

  /**
   * @brief
   *
   * @param [in]prediction
   * @param [in]groundtruth
   * @param [in]source
   *
   * @return
   */
  dstring evaluate(dstring langCode, dstring path_to_files) {
    // First check if the language package is already loaded
    if (!this.containsLanguage(langCode)) {
      // No,let's try to load it!
      this.loadLanguage(langCode);
    }

    //auto links = File(to!string(path_to_files) ~ "groundtruth/links.txt", "r");

    //logInfo("Processing " ~ to!string(path_to_files) ~ "groundtruth/links.txt");

    //dstring raw;
    dstring prediction;
    dstring source;
    dstring groundtruth;

    // Create the cross linkage builder
    //DEPRECATED: auto linkage = new CrossLinkage(this.getLanguageByLangCode(langCode));
    auto linker = new AlignmentLinker(this.getLanguageByLangCode(langCode));

    //foreach (line; links.byLine) {
    //string buffer = to!string(line);
    //buffer = buffer.replace("\n", "");
    auto existence = to!string(path_to_files) ~ "prediction.json";
    if (existence.exists) {

      writeln("Working with file: " ~ existence);

      // Read in all raw data
      //raw = to!dstring(readText(to!string(path_to_files) ~ "raw.txt"));
      prediction = to!dstring(readText(to!string(path_to_files) ~ "prediction.json"));
      source = to!dstring(readText(to!string(path_to_files) ~ "source.json"));
      groundtruth = to!dstring(readText(to!string(path_to_files) ~ "groundtruth.json"));

      /*
      // Build the internal representation
      auto rRepr = new RawRepr(raw);
      auto pRepr = new PredictionRepr(prediction, rRepr);
      auto sRepr = new SourceRepr(source, rRepr);
      auto gRepr = new GroundtruthRepr(groundtruth, sRepr);
      */
      //RawRepr rRepr = new RawRepr(raw);

      Result result = this.dataReader.parse(source, groundtruth, prediction);
      SourceRepr sRepr = result[0];
      GroundtruthRepr gRepr = result[1];
      PredictionRepr pRepr = result[2];

      // Initialize the cross linker
      //DEPRECATED: linkage.initialize(rRepr, sRepr, gRepr, pRepr);
      linker.initialize(sRepr, gRepr, pRepr);

      // Build and initialize the internal structures
      //DEPRECATED: linkage.build();
      linker.build();

      // Evaluate the alignment between source, prediction and groundtruth
      //DEPRECATED: linkage.evaluate();
      linker.evaluate();

      //DEPRECATED: linkage.serializeAlignmentTo(path_to_files);
      linker.serializeAlignmentTo(path_to_files);
    }
    //}

    //links.close();

    logInfo(">> Fully evaluated prediction!");

    //DEPRECATED: return linkage.getResults();
    return linker.getResults();
  }

  void populateLanguageDictionaries() {

  }

  ref Language getLanguageByLangCode(dstring langCode) {
    return this.languages[langCode];
  }

  bool containsLanguage(dstring langCode) {
    if (langCode in this.languages) {
      return true;
    }

    return false;
  }

  void loadLanguage(dstring langCode) {
    write("The Language Dictionaries for ", langCode, " are not cached, will do this now ... ");
    this.languages[langCode] = new Language("/data/data/", to!string(langCode));
    writeln(" done.");
  }

  /**
   * Array containing all language dictionaries.
   */
  Language[dstring] languages;

  DataReader dataReader;
}
