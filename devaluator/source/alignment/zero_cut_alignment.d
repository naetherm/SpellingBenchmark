// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.alignment.zero_cut_alignment;

import std.algorithm;
import std.algorithm.mutation;
import std.container;
import std.math;
import std.range;
import std.stdio;
import std.string;
import std.conv;
import std.typecons: tuple, Tuple;

import devaluator.utils.queue;
import devaluator.utils.nlp: NGram;

/**
 * @class
 * AlignedGroupItem
 *
 * @brief
 *
 */
class AlignedGroupItem {

  this() {
    this.mnLeft = long.init;
    this.mnRight = long.init;
  }

  this(long nLeft, long nRight) {
    this.mnLeft = nLeft;
    this.mnRight = nRight;
  }

  long mnLeft;
  long mnRight;
}

/**
 * @class
 * AlignedGroup
 *
 * @brief
 *
 */
class AlignedGroup {

  this() {
    this.mcFirst = new AlignedGroupItem();
    this.mcSecond = new AlignedGroupItem();
    this.mbBuilt = false;
  }

  this(AlignedGroupItem cFirst, AlignedGroupItem cSecond) {
    this.mcFirst = cFirst;
    this.mcSecond = cSecond;
    this.mbBuilt = true;
  }

  bool valid() const pure nothrow @safe { return this.mbBuilt; }

  void toString(scope void delegate(const(char)[]) sink) const {
    sink("AlignedGroup:\n");
    sink("\tFirst: ["); sink(to!string(this.mcFirst.mnLeft)); sink(", "); sink(to!string(this.mcFirst.mnRight)); sink(")\n");
    sink("\tSecond: ["); sink(to!string(this.mcSecond.mnLeft)); sink(", "); sink(to!string(this.mcSecond.mnRight)); sink(")\n");
  }

  long length() const {
    return (this.mcFirst.mnRight - this.mcFirst.mnLeft);
  }

  ref AlignedGroupItem first() { return this.mcFirst; }

  ref AlignedGroupItem second() { return this.mcSecond; }

  AlignedGroupItem mcFirst;
  AlignedGroupItem mcSecond;
  bool mbBuilt;

}

/**
 * @class
 * UnalignedGroupItem
 *
 * @brief
 *
 */
class UnalignedGroupItem {

  this(long nLeft, long nRight, bool bEmpty) {
    this.mnLeft = nLeft;
    this.mnRight = nRight;
    this.mbEmptyGroup = bEmpty;
  }

  long diffLength() const pure nothrow @safe {
    return this.mnRight - this.mnLeft;
  }

  bool empty() const pure nothrow @safe {
    return this.mbEmptyGroup;
  }

  long mnLeft;
  long mnRight;
  bool mbEmptyGroup;
}

/**
 * @class
 * UnalignedGroup
 *
 * @brief
 *
 */
class UnalignedGroup {

  this() {
    this.mbBuilt = false;
  }

  this(UnalignedGroupItem cFirst, UnalignedGroupItem cSecond) {
    this.mcFirst = cFirst;
    this.mcSecond = cSecond;
    this.mbBuilt = true;
  }

  bool empty() const pure nothrow @safe {
    return this.mcFirst.mbEmptyGroup || this.mcSecond.mbEmptyGroup;
  }

  bool valid() const pure nothrow @safe {
    return this.mbBuilt;
  }

  long diffFirst() const pure nothrow @safe {
    return this.mcFirst.diffLength();
  }

  long diffSecond() const pure nothrow @safe {
    return this.mcSecond.diffLength();
  }

  void toString(scope void delegate(const(char)[]) sink) const {
    sink("UnalignedGroup: ");
    if (this.mcFirst.empty()) {
      sink("\tFirst: ("); sink(to!string(this.mcFirst.mnLeft)); sink(", "); sink(to!string(this.mcFirst.mnRight)); sink(")\n");
    } else {
      sink("\tFirst: ["); sink(to!string(this.mcFirst.mnLeft)); sink(", "); sink(to!string(this.mcFirst.mnRight)); sink(")\n");
    }
    if (this.mcSecond.empty()) {
      sink("\tSecond: ("); sink(to!string(this.mcSecond.mnLeft)); sink(", "); sink(to!string(this.mcSecond.mnRight)); sink(")\n");
    } else {
      sink("\tSecond: ["); sink(to!string(this.mcSecond.mnLeft)); sink(", "); sink(to!string(this.mcSecond.mnRight)); sink(")\n");
    }
  }

  UnalignedGroupItem mcFirst;
  UnalignedGroupItem mcSecond;
  bool mbBuilt;
}



alias Result = Tuple!(Array!(AlignedGroup), Array!(UnalignedGroup));
alias SingleResult = Tuple!(AlignedGroup, Array!(UnalignedGroup));


/**
 * @class
 * ZeroCutAlignment
 *
 * @brief
 * ZeroCutAlignment implementation, as in the corresponding proposed article.
 *
 * TODO(naetherm): More documentation.
 */
class ZeroCutAlignment(TType) {
  /**
   * @brief
   * Constructor.
   *
   * @param [in]first
   * @param [in]second
   * @param [in]bAutoDiffEvaluation
   * @param [in]fDiffMultiplicator
   */
  this(TType[] first, TType[] second, bool bAutoDiffEvaluation = true, float fDiffMultiplicator = 1.0) {
    this.first = first;
    this.second = second;
    this.mbAutoDiffEvaluation = bAutoDiffEvaluation;
    this.diffMultiplier = fDiffMultiplicator;
  }

  /**
   * @brief
   * Responsible for building the best alignment between the two given sequences of tokens.
   * Thereby this method produces two informative sets:
   * - Array!AlignedGroup
   * - Array!UnalignedGroup
   *
   * The first one represents all tokens that the cutter was able to directly align, because they 
   * are overlapping, the second group contains all found groups of unaligned items. As an example
   * consider the following two sequences (the aligned items are in <<>> and connected through 
   * the level in the center):
   * <<The quick>> brawn fox <<fox .>>
   *   |||||||||            //////
   * <<The quick>> brown <<fox .>>
   * One may directly note that the elements "brawn fox" and "brown" are not within this aligned 
   * group because they have no overlapping items. These grouping becomes an entry wihtin the 
   * UnalignedGroup array, which will later on be merged with additional results of other 
   * ZeroCutAlignment applications.
   *
   * @see AlignmentMerger
   */
  Result build() {
    // The queue that holds all of our still unaligned elements
    Array!(AlignedGroup) cAlignedGroups;
    Array!(UnalignedGroup) cUnalignedGroups;

    // 1) Build the alignment information

    // First, add the whole sequences as unaligned group
    GrowableCircularQueue!(UnalignedGroup) cQueue = new GrowableCircularQueue!(UnalignedGroup)();

    cQueue.push(
      new UnalignedGroup(
        new UnalignedGroupItem(0, this.first.length, false),
        new UnalignedGroupItem(0, this.second.length, false)
      )
    );

    // Loop through the queue until it is empty
    while(!cQueue.empty()) {
      // Find alignments and unaligned blocks
      auto result = this.buildAlignment(cQueue, cQueue.pop());

      // The first elements of the returned tuple are the found alignments
      
      if (result[0].valid()) {
        cAlignedGroups.insertBack(result[0]);
      }
      
      foreach(e; result[1]) {
        if (e.valid()) {
          cUnalignedGroups.insertBack(e);
        }
      }

      // The second group are definitively unaligned groups
    }

    // Anythign left to do?

    return tuple(cAlignedGroups, cUnalignedGroups);
  }

  // TODO(naetherm)
  // - Extract the information of void build() and split it up into these two separate methods!
  /**
   * @brief
   * 
   * @param [in]cQueue
   * @param [in]cUnalignedGroup
   */
  private SingleResult buildAlignment(
    ref GrowableCircularQueue!(UnalignedGroup) cQueue,
    UnalignedGroup cUnalignedGroup) {
    // The results for both groups
    AlignedGroup cResultAlignedGroup = new AlignedGroup();
    Array!(UnalignedGroup) cResultUnalignedGroups = Array!(UnalignedGroup)();

    long nFL = to!(long)(cUnalignedGroup.mcFirst.mnLeft);
    long nFR = to!(long)(cUnalignedGroup.mcFirst.mnRight);
    long nSL = to!(long)(cUnalignedGroup.mcSecond.mnLeft);
    long nSR = to!(long)(cUnalignedGroup.mcSecond.mnRight);
    
    // Determine the max length of both elements
    long nMaxLen = min(cUnalignedGroup.diffFirst(), cUnalignedGroup.diffSecond());
    
    // Calculate the absolute difference between those two groups
    long nDiff = abs(cUnalignedGroup.diffSecond() - cUnalignedGroup.diffFirst());
    if (nDiff == 0) {
      nDiff = 1;
    }

    //writeln("Working on: ");
    //writeln(cUnalignedGroup);

    // Generate the n-grams
    bool bFoundAlignment = false;
    
    for (auto n = nMaxLen; n > 0; n--) {
      //writeln("\tn: ", n);
      // If we found an alignment let's break out
      if (bFoundAlignment) { break; }
      // Generate the n-grams
      auto cFirstGram = new NGram!TType(this.first[nFL..nFR], n);
      auto cSecondGram = new NGram!TType(this.second[nSL..nSR], n);

      // Loop thorugh all generated n-grams and search for similarities
      foreach (fidx; 0..cFirstGram.getGrams().length) {
        if (bFoundAlignment) { break; }
        foreach (sidx; 0..cSecondGram.getGrams().length) {
          auto f = cFirstGram.getGram(fidx);
          auto s = cSecondGram.getGram(sidx);

          // If both are exact equal and the positional different between them is between a certain threshold
          //if (equal(f, s) && (abs((nSL+to!long(sidx))-(nFL+to!long(fidx))) <= nDiff*this.diffMultiplier)) {
          if (equal(f, s) && (abs((to!long(sidx))-(to!long(fidx))) <= nDiff*this.diffMultiplier)) {
            // Found a group, create the aligned group and break out of the loop
            bFoundAlignment = true;
            //writeln("\nEquality: ", equal(f, s), " :: with abs diff ", abs((nSL+to!long(sidx))-(nFL+to!long(fidx))), " and max diff ", nDiff*this.diffMultiplier);
            //writeln("Found alignment between: ", f[0],"->", s[0], " :: ", f[f.length-1],"->", s[s.length-1]);
            //writeln("\t", cUnalignedGroup.mcFirst.mnLeft+fidx, "..", cUnalignedGroup.mcFirst.mnLeft+fidx+n);
            //writeln("\t", cUnalignedGroup.mcSecond.mnLeft+sidx, "..", cUnalignedGroup.mcSecond.mnLeft+sidx+n);
            cResultAlignedGroup = new AlignedGroup(
              new AlignedGroupItem(nFL+fidx, nFL+fidx+n),
              new AlignedGroupItem(nSL+sidx, nSL+sidx+n)
            );

            break;
          }
        }
      }
    }

    //writeln("Found group: ");
    //writeln(cResultAlignedGroup);

    // Dependent on the result of the aligned group add the found unaligned parts to another region
    if (cResultAlignedGroup.valid()) {
      // There are 0 to 2 unaligned groups
      // First 
      if ((cResultAlignedGroup.mcFirst.mnLeft == cUnalignedGroup.mcFirst.mnLeft) &&
          (cResultAlignedGroup.mcFirst.mnRight == cUnalignedGroup.mcFirst.mnRight) &&
          (cResultAlignedGroup.mcSecond.mnLeft == cUnalignedGroup.mcSecond.mnLeft) &&
          (cResultAlignedGroup.mcSecond.mnRight == cUnalignedGroup.mcSecond.mnRight)) {
        // Perfect catch. Nothing to do here.
      } else {
        // May the if wars begin
        if ((cResultAlignedGroup.mcFirst.mnLeft == cUnalignedGroup.mcFirst.mnLeft) &&
            (cResultAlignedGroup.mcSecond.mnLeft == cUnalignedGroup.mcSecond.mnLeft)) {
          // Nothing to do, the left side is okay
        } else {
          //writeln("\tNew unaligned block[LEFT]:");
          //writeln("\t\t", cUnalignedGroup.mcFirst.mnLeft, cResultAlignedGroup.mcFirst.mnLeft);
          //writeln("\t\t", cUnalignedGroup.mcSecond.mnLeft, cResultAlignedGroup.mcSecond.mnLeft);
          cQueue.push(
            new UnalignedGroup(
              new UnalignedGroupItem(cUnalignedGroup.mcFirst.mnLeft, cResultAlignedGroup.mcFirst.mnLeft, cUnalignedGroup.mcFirst.mnLeft == cResultAlignedGroup.mcFirst.mnLeft),
              new UnalignedGroupItem(cUnalignedGroup.mcSecond.mnLeft, cResultAlignedGroup.mcSecond.mnLeft, cUnalignedGroup.mcSecond.mnLeft == cResultAlignedGroup.mcSecond.mnLeft)
            )
          );
        }

        if ((cResultAlignedGroup.mcFirst.mnRight == cUnalignedGroup.mcFirst.mnRight) &&
            (cResultAlignedGroup.mcSecond.mnRight == cUnalignedGroup.mcSecond.mnRight)) {
          // Nothing to do, the right side is okay
        } else {
          //writeln("\tNew unaligned block[RIGHT]:");
          //writeln("\t\t", cResultAlignedGroup.mcFirst.mnRight, cUnalignedGroup.mcFirst.mnRight);
          //writeln("\t\t", cResultAlignedGroup.mcSecond.mnRight, cUnalignedGroup.mcSecond.mnRight);
          cQueue.push(
            new UnalignedGroup(
              new UnalignedGroupItem(cResultAlignedGroup.mcFirst.mnRight, cUnalignedGroup.mcFirst.mnRight, cResultAlignedGroup.mcFirst.mnRight == cUnalignedGroup.mcFirst.mnRight),
              new UnalignedGroupItem(cResultAlignedGroup.mcSecond.mnRight, cUnalignedGroup.mcSecond.mnRight, cResultAlignedGroup.mcSecond.mnRight == cUnalignedGroup.mcSecond.mnRight)
            )
          );
        }
      }

      // Second

      // If there is an aligned group add the resulting unaligned elements to the queue
      //for (size_t i = 0; i < cResultUnalignedGroups.length; i++) {
      //  cQueue.push(cResultUnalignedGroups[i]);
      //}
      return tuple(cResultAlignedGroup, cResultUnalignedGroups);
    } else {
      // There was not a single aligned group, so the whole group cannot be aligned
      cResultUnalignedGroups.insertBack(cUnalignedGroup);
      // No aligned group, add the full stack of unaligned elements to the final list of unaligned elements
      return tuple(cResultAlignedGroup, cResultUnalignedGroups);
    }

    // Done, should never reach this point!
  }

  /**
   * @brief
   * 
   */
  private void resolveAlignments(ref Array!(AlignedGroup) cAlignedGroups, ref Array!(UnalignedGroup) cUnalignedGroups) {

  }

  /**
   * @brief
   * Builds the internal representation for the alignment and the resulting
   * gaps of both input arrays.
   */
  void buildBackup() {
    // Determine the max length to go
    ulong max_len = min(this.first.length, this.second.length);
    // Additionally, calculate the difference. We will use this later on
    ulong diff = abs(this.first.length - this.second.length);

    // Loop through all
    for (auto n = max_len; n > 0; n--) {
      auto first_gram = new NGram!TType(this.first, n);
      auto second_gram = new NGram!TType(this.second, n);

      for (ulong fidx = 0; fidx < first_gram.getGrams().length; fidx++) {
        for (ulong sidx = 0; sidx < second_gram.getGrams().length; sidx++) {
      //foreach (ulong fidx, f; first_gram.getGrams()) {
      //  foreach (ulong sidx, s; second_gram.getGrams()) {
          auto f = first_gram.getGram(fidx);
          auto s = second_gram.getGram(sidx);
          if (equal(f, s) && (abs(fidx-sidx) <= diff*this.diffMultiplier)) {
            // If this is the first occurence to add, just add it
            if (this.spanGroupsF.length == 0) {
              ulong[] f_group;
              ulong[] s_group;
              for (ulong f_elem = fidx; f_elem < fidx + n; f_elem++) { f_group ~= f_elem; }
              for (ulong s_elem = sidx; s_elem < sidx + n; s_elem++) { s_group ~= s_elem; }
              this.spanGroupsF.insertBack(f_group.dup);
              this.spanGroupsS.insertBack(s_group.dup);
            } else {
              // There are already groups inside the span groups, check if this items is available
              bool alreadyIncluded = false;

              foreach (ulong[] f_group, ulong[] s_group; zip(this.spanGroupsF[], this.spanGroupsS[])) {
                if (((f_group[0] <= fidx) && (fidx <= f_group[$-1])) || ((s_group[0] <= sidx) && (sidx <= s_group[$-1]))) {
                  alreadyIncluded = true;
                }
              }

              if (!alreadyIncluded) {
                ulong[] f_group;
                ulong[] s_group;
                for (ulong f_elem = fidx; f_elem < fidx + n; f_elem++) { f_group ~= f_elem; }
                for (ulong s_elem = sidx; s_elem < sidx + n; s_elem++) { s_group ~= s_elem; }
                this.spanGroupsF.insertBack(f_group.dup);
                this.spanGroupsS.insertBack(s_group.dup);
              }
            }
          }
        }
      }
    }

    // Now extrude all captured groups
    foreach(ulong[] f_group, ulong[] s_group; zip(this.spanGroupsF[], this.spanGroupsS[])) {
      //ulong[] f_group = group[0];
      //ulong[] s_group = group[1];
      for (ulong idx = 0; idx < f_group.length; idx++) {
        bool addThis = true;
        // Check if we already have this alignment information
        foreach (a_elem; this.alignedGroups) {
          if (f_group[idx] == a_elem[0]) {
            addThis = false;
          }
        }
        // Add me
        if (addThis) {
          ulong[] newElement;
          newElement ~= f_group[idx];
          newElement ~= s_group[idx];
          this.alignedGroups.insertBack(newElement.dup);
        }
      }
    }

    // Some helper structures
    long[] firstAssignGroup = new long[this.first.length];
    long[] secondAssignGroup = new long[this.second.length];
    fill(firstAssignGroup, -1);
    fill(secondAssignGroup, -1);
    for (long idx = 0; idx < this.alignedGroups.length; idx++) {
      auto group = this.alignedGroups[idx];
      firstAssignGroup[group[0]] = idx;
      secondAssignGroup[group[1]] = idx;
    }

    //
    // Generate the gap groups
    //
    ulong fidx = 0;
    ulong sidx = 0;
    long f_start = -1;
    long s_start = -1;
    bool f_freeze = false;
    bool s_freeze = false;
    while (fidx < this.first.length && sidx < this.second.length) {
      if ((firstAssignGroup[fidx] != -1) && (secondAssignGroup[sidx] != -1)) {
        if ((f_start != -1) && (s_start != -1)) {
          for (long f = f_start; f < fidx; f++) {
            for (long s = s_start; s < sidx; s++) {
              long[] group;
              // TODO(naetherm): We've swapped the order here!
              group ~= f;
              group ~= s;
              this.gapGroups.insertBack(group.dup);
            }
          }
        }
        if ((f_start != -1) && (s_start == -1)) {
          for (long f = f_start; f < fidx; f++) {
            long[] group;
            group ~= f;
            group ~= -1;
            this.gapGroups.insertBack(group.dup);
          }
        }
        if ((f_start == -1) && (s_start != -1)) {
          for (long s = s_start; s < sidx; s++) {
            long[] group;
            group ~= -1;
            group ~= s;
            this.gapGroups.insertBack(group.dup);
          }
        }
        // Reset everything
        s_start = -1; f_start = -1;
        sidx += 1; fidx += 1;
        s_freeze = false; f_freeze = false;
      } else if ((firstAssignGroup[fidx] == -1) && (secondAssignGroup[sidx] == -1)) {
        if (f_start == -1) { f_start = fidx; }
        if (s_start == -1) { s_start = sidx; }
        fidx += 1;
        sidx += 1;
      } else if ((firstAssignGroup[fidx] == -1) && (secondAssignGroup[sidx] != -1)) {
        s_freeze = true;
        if (f_start == -1) { f_start = fidx; }
        fidx += 1;
      } else if ((firstAssignGroup[fidx] != -1) && (secondAssignGroup[sidx] == -1)) {
        f_freeze = true;
        if (s_start == -1) { s_start = sidx; }
        sidx += 1;
      }
    }

    // Finalizing: Are there any open groups left?
    if ((f_start != -1) && (s_start != -1)) {
      for (long f = f_start; f < fidx; f++) {
        for (long s = s_start; s < sidx; s++) {
          long[] group;
          group ~= f;
          group ~= s;
          this.gapGroups.insertBack(group.dup);
        }
      }
    }
    if ((f_start != -1) && (s_start == -1)) {
      for (long f = f_start; f < fidx; f++) {

        long[] group;
        group ~= f;
        group ~= -1;
        this.gapGroups.insertBack(group.dup);
      }
    }
    if ((f_start == -1) && (s_start != -1)) {
      for (long s = s_start; s < sidx; s++) {
        long[] group;
        group ~= -1;
        group ~= s;
        this.gapGroups.insertBack(group.dup);
      }
    }

    if (fidx < firstAssignGroup.length) {
      for (long f = fidx; f < firstAssignGroup.length; f++)  {
        long[] group;
        group ~= f;
        group ~= -1;
        this.gapGroups.insertBack(group.dup);
      }
    }
    if (sidx < secondAssignGroup.length) {
      for (long s = sidx; s < secondAssignGroup.length; s++)  {
        long[] group;
        group ~= -1;
        group ~= s;
        this.gapGroups.insertBack(group.dup);
      }
    }
  }

  TType[] first;
  TType[] second;
  bool mbAutoDiffEvaluation;
  float diffMultiplier;

  ulong[ulong] alignment;

  Array!(ulong[]) spanGroupsF;
  Array!(ulong[]) spanGroupsS;
  Array!(ulong[]) alignedGroups;
  Array!(long[]) gapGroups;
}

unittest {
  import devaluator.alignment.zero_cut_alignment;

  dstring[] first = ["And", "another", "test", "sentence", "."];
  dstring[] second = ["And", "another", "test", "sentence", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);

  Result results = zca.build();

  writeln("results[0]: "); 
  foreach(i; 0..results[0].length) {
    writeln(results[0][i]);
  }
  writeln("results[1]: ");
  foreach(i; 0..results[1].length) {
    writeln(results[1][i]);
  }
}

unittest {
  import devaluator.alignment.zero_cut_alignment;

  dstring[] first = ["And", "another", "text", "sentence", "."];
  dstring[] second = ["And", "another", "test", "sentence", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);

  Result results = zca.build();

  writeln("results[0]: "); 
  foreach(i; 0..results[0].length) {
    writeln(results[0][i]);
  }
  writeln("results[1]: ");
  foreach(i; 0..results[1].length) {
    writeln(results[1][i]);
  }
}

unittest {
  import devaluator.alignment.zero_cut_alignment;

  dstring[] first = ["And", "another", "test", "test", "sentence", "."];
  dstring[] second = ["And", "another", "test", "sentence", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);

  Result results = zca.build();
}

unittest {
  import devaluator.alignment.zero_cut_alignment;

  dstring[] first = ["The", "quirk", "brown", "fox", "fox", "."];
  dstring[] second = ["The", "quick", "brown", "fox", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);

  Result results = zca.build();
}

unittest {
  import devaluator.alignment.zero_cut_alignment;

  dstring[] first = ["The", "quirk", "brown", "fox", "fox", "."];
  dstring[] second = ["The", "quick", "brown", "fix", "fax", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);

  Result results = zca.build();
}

unittest {
  import devaluator.alignment.zero_cut_alignment;

  dstring[] first = ["This", "is", "the", "first", ",", "obviously", "simple", ",", "sentence", "."];
  dstring[] second = ["This", "is", "the", "first", ",", "obviously", "simple", ",", "sentence", "."];

  auto zca = new ZeroCutAlignment!(dstring)(first, second);

  Result results = zca.build();

  writeln("results[0]: "); 
  foreach(i; 0..results[0].length) {
    writeln(results[0][i]);
  }
  writeln("results[1]: ");
  foreach(i; 0..results[1].length) {
    writeln(results[1][i]);
  }
}