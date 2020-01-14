// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.alignment.gap_table;

import std.container;
import std.conv;
import std.math;
import std.string;

import devaluator.utils.types;

/** 
 * @class
 * GapItem
 *
 * @brief
 * A single element of a gap.
 */
class GapItem {
  /** 
   * Constructor.
   * Params:
   *   nLeft = outer left index (included)
   *   nRight = outer right index (excluded)
   *   bBetween = True if this gap is between two tokens (without representing a token by itself)
   */
  this(long nLeft, long nRight, bool bBetween) {
    this.mnLeft = nLeft;
    this.mnRight = nRight;
    this.mbBetween = bBetween;
  }

  long left() const pure nothrow @safe { return this.mnLeft; }

  long right() const pure nothrow @safe { return this.mnRight; }

  long length() const  pure nothrow @safe { return this.mnRight - this.mnLeft; }

  bool between() const pure nothrow @safe { return ((this.mnRight - this.mnLeft) == 0); }

  bool empty() const pure nothrow @safe { return this.between(); }

  long mnLeft;
  long mnRight;
  bool mbBetween;
}

/**
 * @class 
 * GapToken
 *
 * @brief
 * A single token of the gap information.
 */
class GapToken {

  this(GroupAssociation nAssociation, GapItem cPrediction, GapItem cOther) {
    this.mnAssociation = nAssociation;
    this.mcPrediction = cPrediction;
    this.mcOther = cOther;
  }

  ref GroupAssociation assoc() { return this.mnAssociation; }

  long diff() const { return abs(this.mcOther.length() - this.mcPrediction.length()); }

  ref GapItem pred() { return this.mcPrediction; }

  ref GapItem other() { return this.mcOther; }
  
  void toString(scope void delegate(const(char)[]) sink) const {
    sink("\tPrediction [");
    if (this.mcPrediction.empty()) {
      sink("("); 
      sink(to!string(this.mcPrediction.mnLeft)); 
      sink(","); 
      sink(to!string(this.mcPrediction.mnRight)); 
      sink(")");
    } else {
      sink("["); 
      sink(to!string(this.mcPrediction.mnLeft)); 
      sink(","); 
      sink(to!string(this.mcPrediction.mnRight)); 
      sink(")");
    }
    sink("]\n");
    sink("\tOther [");
    if (this.mcOther.empty()) {
      sink("("); 
      sink(to!string(this.mcOther.mnLeft)); 
      sink(","); 
      sink(to!string(this.mcOther.mnRight)); 
      sink(")");
    } else {
      sink("["); 
      sink(to!string(this.mcOther.mnLeft)); 
      sink(","); 
      sink(to!string(this.mcOther.mnRight)); 
      sink(")");
    }
    sink("]\n");
  }

  GroupAssociation mnAssociation;
  GapItem mcPrediction;
  GapItem mcOther;

}

class GapTable {
  
  /**
   * @brief
   * Default constructor.
   */
  this() {}

  /**
   * @brief
   * Adds an additional token. According to the association of the gap token it will be added to 
   * another list.
   *
   * @param [in]cToken
   * New token to add to gap information list.
   */
  void add(GapToken cToken) { 
    if (cToken.assoc() == GroupAssociation.PRD2GRT) {
      this.mlstP2G.insertBack(cToken);
    } else {
      this.mlstP2S.insertBack(cToken);
    }
  }

  /**
   * @brief
   * Returns, according to the given association type, the list containing all gap information.
   *
   * @param [in]nAssociation
   * The association for which we want to receive the list of gaps.
   */
  ref Array!(GapToken) get(GroupAssociation nAssociation) { 
    if (nAssociation == GroupAssociation.PRD2GRT) {
      return this.mlstP2G;
    } else {
      return this.mlstP2S;
    }
  }

  void toString(scope void delegate(const(char)[]) sink) const {
    sink("GapTable [\n");
    sink("P2G: \n");
    foreach(e; this.mlstP2G) {
      sink(to!string(e));
    }
    sink("P2S: \n");
    foreach(e; this.mlstP2S) {
      sink(to!string(e));
    }
    sink("]\n");
  }

  void replaceGapTokens(GroupAssociation nGroup, GapToken[] gaps) {
    if (nGroup == GroupAssociation.PRD2GRT) {
      this.mlstP2G = Array!(GapToken)(gaps);
    } else {
      this.mlstP2S = Array!(GapToken)(gaps);
    }
  }

  ref Array!(GapToken) p2g() { return this.mlstP2G; }

  ref Array!(GapToken) p2s() { return this.mlstP2S; }

  ref GapToken p2gAt(ulong nIdx) { return this.mlstP2G[nIdx]; }

  ref GapToken p2sAt(ulong nIdx) { return this.mlstP2S[nIdx]; }

  long lengthP2G() const { return this.mlstP2G.length; }

  long lengthP2S() const { return this.mlstP2S.length; }

  Array!(GapToken) mlstP2G;
  Array!(GapToken) mlstP2S;
}

class GapArticle {

  this() {

  }

  GapTable[ulong] sentences;
}