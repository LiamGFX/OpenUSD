%{
//
// Copyright 2016 Pixar
//
// Licensed under the terms set forth in the LICENSE.txt file available at
// https://openusd.org/license.
//

#include "pxr/pxr.h"
#include "pxr/base/arch/fileSystem.h"
#include "pxr/base/tf/errorMark.h"
#include "pxr/base/tf/stringUtils.h"
#include "pxr/usd/sdf/textParserContext.h"
#include "pxr/usd/sdf/parserHelpers.h"
#include "pxr/usd/sdf/schema.h"

// Token table from yacc file
#include "textFileFormat.tab.h"

#ifndef fileno
#define fileno(fd) ArchFileNo(fd)
#endif
#ifndef isatty
#define isatty(fd) ArchFileIsaTTY(fd)
#endif

using std::map;
using std::vector;

PXR_NAMESPACE_USING_DIRECTIVE

#define YYSTYPE Sdf_ParserHelpers::Value

// As a pure parser, we must define the following
#define YY_DECL int textFileFormatYylex(YYSTYPE *yylval_param, yyscan_t yyscanner)

// The context object will be used to store global state for the parser.
#define YY_EXTRA_TYPE Sdf_TextParserContext *

%}

/* Configuration options for flex */
%option noyywrap
%option nounput
%option reentrant
%option bison-bridge

/* character classes
  * defines UTF-8 encoded byte values for standard ASCII
  * and multi-byte UTF-8 character sets
  * valid multi-byte UTF-8 sequences are as follows:
  * For an n-byte encoded UTF-8 character, the last n-1 bytes range [\x80-\xbf]
  * 2-byte UTF-8 characters, first byte in range [\xc2-\xdf]
  * 3-byte UTF-8 characters, first byte in range [\xe0-\xef]
  * 4-byte UTF-8 characters, first byte in range [\xf0-\xf4]
  * ASCII characters span [\x41-\x5a] (upper case) [\x61-\x7a] (lower case) [\x30-39] (digits)
  */
ALPHA1      [\x41-\x5a]
ALPHA2      [\x61-\x7a]
DIGIT       [\x30-\x39]
UEND        [\x80-\xbf]
U2PRE       [\xc2-\xdf]
U3PRE       [\xe0-\xef]
U4PRE       [\xf0-\xf4]
UNDER       [_]
DASH        [\-]
BAR         [\|]
ALPHA       {ALPHA1}|{ALPHA2}
ALPHANUM    {ALPHA}|{DIGIT}
UTF8X       {U2PRE}{UEND}|{U3PRE}{UEND}{UEND}|{U4PRE}{UEND}{UEND}{UEND}
UTF8        {ALPHANUM}|{UTF8X}
UTF8NODIG   {ALPHA}|{UTF8X}
UTF8U       {UTF8}|{UNDER}
UTF8NODIGU  {UTF8NODIG}|{UNDER}
UTF8UD      {UTF8U}|{DASH}
UTF8UDB     {UTF8UD}|{BAR}

/* States */
%x SLASHTERIX_COMMENT

%%

    /* skip over whitespace and comments */
    /* handle the first line # comment specially, since it contains the
       magic token */
[[:blank:]]+ {}
"#"[^\r\n]* {
        if (yyextra->sdfLineNo == 1) {
            (*yylval_param) = std::string(yytext, yyleng);
            return TOK_MAGIC;
        }
    }
"//"[^\r\n]* {}
"/*" BEGIN SLASHTERIX_COMMENT ;
<SLASHTERIX_COMMENT>.|\n|\r ;
<SLASHTERIX_COMMENT>"*/" BEGIN INITIAL ;

    /* newline is returned as TOK_NL
     * Note that newlines embedded in quoted strings and tuples are counted
     * as part of the token and do NOT emit a separate TOK_NL.
     */
((\r\n)|\r|\n) {
        yyextra->sdfLineNo++;
        return TOK_NL;
    }

    /* literal keywords.  we return the yytext so that the yacc grammar
       can make use of it. */
"add"                 { (*yylval_param) = std::string(yytext, yyleng); return TOK_ADD; }
"append"              { (*yylval_param) = std::string(yytext, yyleng); return TOK_APPEND; }
"class"               { (*yylval_param) = std::string(yytext, yyleng); return TOK_CLASS; }
"config"              { (*yylval_param) = std::string(yytext, yyleng); return TOK_CONFIG; }
"connect"             { (*yylval_param) = std::string(yytext, yyleng); return TOK_CONNECT; }
"custom"              { (*yylval_param) = std::string(yytext, yyleng); return TOK_CUSTOM; }
"customData"          { (*yylval_param) = std::string(yytext, yyleng); return TOK_CUSTOMDATA; }
"default"             { (*yylval_param) = std::string(yytext, yyleng); return TOK_DEFAULT; }
"def"                 { (*yylval_param) = std::string(yytext, yyleng); return TOK_DEF; }
"delete"              { (*yylval_param) = std::string(yytext, yyleng); return TOK_DELETE; }
"dictionary"          { (*yylval_param) = std::string(yytext, yyleng); return TOK_DICTIONARY; }
"displayUnit"         { (*yylval_param) = std::string(yytext, yyleng); return TOK_DISPLAYUNIT; }
"doc"                 { (*yylval_param) = std::string(yytext, yyleng); return TOK_DOC; }
"inherits"            { (*yylval_param) = std::string(yytext, yyleng); return TOK_INHERITS; }
"kind"                { (*yylval_param) = std::string(yytext, yyleng); return TOK_KIND; }
"nameChildren"        { (*yylval_param) = std::string(yytext, yyleng); return TOK_NAMECHILDREN; }
"None"                { (*yylval_param) = std::string(yytext, yyleng); return TOK_NONE; }
"offset"              { (*yylval_param) = std::string(yytext, yyleng); return TOK_OFFSET; }
"over"                { (*yylval_param) = std::string(yytext, yyleng); return TOK_OVER; }
"payload"             { (*yylval_param) = std::string(yytext, yyleng); return TOK_PAYLOAD; }
"permission"          { (*yylval_param) = std::string(yytext, yyleng); return TOK_PERMISSION; }
"prefixSubstitutions" { (*yylval_param) = std::string(yytext, yyleng); return TOK_PREFIX_SUBSTITUTIONS; }
"prepend"             { (*yylval_param) = std::string(yytext, yyleng); return TOK_PREPEND; }
"properties"          { (*yylval_param) = std::string(yytext, yyleng); return TOK_PROPERTIES; }
"references"          { (*yylval_param) = std::string(yytext, yyleng); return TOK_REFERENCES; }
"relocates"           { (*yylval_param) = std::string(yytext, yyleng); return TOK_RELOCATES; }
"rel"                 { (*yylval_param) = std::string(yytext, yyleng); return TOK_REL; }
"reorder"             { (*yylval_param) = std::string(yytext, yyleng); return TOK_REORDER; }
"rootPrims"           { (*yylval_param) = std::string(yytext, yyleng); return TOK_ROOTPRIMS; }
"scale"               { (*yylval_param) = std::string(yytext, yyleng); return TOK_SCALE; }
"subLayers"           { (*yylval_param) = std::string(yytext, yyleng); return TOK_SUBLAYERS; }
"suffixSubstitutions" { (*yylval_param) = std::string(yytext, yyleng); return TOK_SUFFIX_SUBSTITUTIONS; }
"specializes"         { (*yylval_param) = std::string(yytext, yyleng); return TOK_SPECIALIZES; }
"symmetryArguments"   { (*yylval_param) = std::string(yytext, yyleng); return TOK_SYMMETRYARGUMENTS; }
"symmetryFunction"    { (*yylval_param) = std::string(yytext, yyleng); return TOK_SYMMETRYFUNCTION; }
"timeSamples"         { (*yylval_param) = std::string(yytext, yyleng); return TOK_TIME_SAMPLES; }
"uniform"             { (*yylval_param) = std::string(yytext, yyleng); return TOK_UNIFORM; }
"variantSet"          { (*yylval_param) = std::string(yytext, yyleng); return TOK_VARIANTSET; }
"variantSets"         { (*yylval_param) = std::string(yytext, yyleng); return TOK_VARIANTSETS; }
"variants"            { (*yylval_param) = std::string(yytext, yyleng); return TOK_VARIANTS; }
"varying"             { (*yylval_param) = std::string(yytext, yyleng); return TOK_VARYING; }

 /* unquoted C++ namespaced identifier -- see bug 10775 */
[[:alpha:]_][[:alnum:]_]*(::[[:alpha:]_][[:alnum:]_]*)+ {
        (*yylval_param) = std::string(yytext, yyleng);
        return TOK_CXX_NAMESPACED_IDENTIFIER;
    }

 /* In a Unicode enabled scheme, 'identifiers' are generally
  * categorized as something that begins with something in the
  * XID_Start category followed by zero or more things in the
  * XID_Continue category.  Since the number of characters in
  * these classes are large, we can't explicitly validate them
  * here easily, so the lex rule is pretty permissive with some
  * further validation done in code prior to calling what was
  * read an 'identifier'.  Note this rule will also match
  * standard ASCII strings because the UTF-8 encoded byte 
  * representation is the same for these characters.
  * However, unlike the path lexer, we can guarantee that 
  * prim names aren't something special to be called out here
  * so we can be a little more specific about the kinds of strings
  * we match, particularly to not collide with the pure digit match rule
  * below
  */
{UTF8NODIGU}{UTF8U}* {
    std::string matched = std::string(yytext, yyleng);

    // we perform an extra validation step here
    // to make sure what we matched is actually a valid
    // identifier because we can overmatch UTF-8 characters
    // based on this definition
    if (!SdfSchema::IsValidIdentifier(matched)) {
        return TOK_SYNTAX_ERROR;
    }

    (*yylval_param) = matched;
    return TOK_IDENTIFIER;
}

 /* unquoted namespaced identifiers match any number of colon 
  * delimited identifiers
  */
{UTF8NODIGU}{UTF8U}*(:{UTF8NODIGU}{UTF8U}*)+ {
    std::string matched = std::string(yytext, yyleng);

    // like for regular identifiers, we do a validation
    // check here to prevent overmatching UTF-8 characters
    if (!SdfSchema::IsValidNamespacedIdentifier(matched)) {
        return TOK_SYNTAX_ERROR;
    }

    (*yylval_param) = matched;
    return TOK_NAMESPACED_IDENTIFIER;
}

    /* scene paths */
\<[^\<\>\r\n]*\> {
        (*yylval_param) = Sdf_EvalQuotedString(yytext, yyleng, 1);
        return TOK_PATHREF;
    }

    /* Single '@'-delimited asset references */
@[^@\n]*@ {
        TfErrorMark m;
        (*yylval_param) = 
            Sdf_EvalAssetPath(yytext, yyleng, /* tripleDelimited = */ false);
        return m.IsClean() ? TOK_ASSETREF : TOK_SYNTAX_ERROR;
    }

    /* Triple '@'-delimited asset references. */
@@@([^@\n]|@{1,2}[^@\n]|\\@@@)*@{0,2}@@@ {
        TfErrorMark m;
        (*yylval_param) = 
            Sdf_EvalAssetPath(yytext, yyleng, /* tripleDelimited = */ true);
        return m.IsClean() ? TOK_ASSETREF : TOK_SYNTAX_ERROR;
    }

    /* Singly quoted, single line strings with escapes.
       Note: we handle empty singly quoted strings below, to disambiguate
       them from the beginning of triply-quoted strings.
       Ex: "Foo \"foo\"" */
'([^'\\\r\n]|(\\.))+'   |  /* ' //<- unfreak out coloring code */
\"([^"\\\r\n]|(\\.))+\" {  /* " //<- unfreak out coloring code */
        (*yylval_param) = Sdf_EvalQuotedString(yytext, yyleng, 1);
        return TOK_STRING;
    }

    /* Empty singly quoted strings that aren't the beginning of
       a triply-quoted string. */
''/[^'] {  /* ' // <- keep syntax coloring from freaking out */
        (*yylval_param) = std::string();
        return TOK_STRING;
    }
\"\"/[^"] {
        (*yylval_param) = std::string();
        return TOK_STRING;
    }

    /* Triply quoted, multi-line strings with escapes.
       Ex: """A\n\"B\"\nC""" */
'''([^'\\]|(\\.)|(\\[\r\n])|('{1,2}[^']))*'''        |  /* ' //<- unfreak out coloring code */
\"\"\"([^"\\]|(\\.)|(\\[\r\n])|(\"{1,2}[^"]))*\"\"\" {  /* " //<- unfreak out coloring code */

        unsigned int numlines = 0;
        (*yylval_param) = Sdf_EvalQuotedString(yytext, yyleng, 3, &numlines);
        yyextra->sdfLineNo += numlines;
        return TOK_STRING;
    }

    /* Super special case for negative 0.  We have to store this as a double to
     * preserve the sign.  There is no negative zero integral value, and we
     * don't know at this point what the final stored type will be. */
-0 {
        (*yylval_param) = double(-0.0);
        return TOK_NUMBER;
   }

    /* Positive integers: store as uint64_t if in range, otherwise double. */
[[:digit:]]+ {
        bool outOfRange = false;
        (*yylval_param) = TfStringToUInt64(yytext, &outOfRange);
        if (outOfRange) {
           TF_WARN("Integer literal '%s' on line %d%s%s out of range, parsing "
                   "as double.  Consider exponential notation for large "
                   "floating point values.", yytext, yyextra->sdfLineNo,
                   yyextra->fileContext.empty() ? "" : " in file ",
                   yyextra->fileContext.empty() ? "" :
                   yyextra->fileContext.c_str());
           (*yylval_param) = TfStringToDouble(yytext);
        }
        return TOK_NUMBER;
    }

    /* Negative integers: store as long. */
-[[:digit:]]+ {
        bool outOfRange = false;
        (*yylval_param) = TfStringToInt64(yytext, &outOfRange);
        if (outOfRange) {
           TF_WARN("Integer literal '%s' on line %d%s%s out of range, parsing "
                   "as double.  Consider exponential notation for large "
                   "floating point values.", yytext, yyextra->sdfLineNo,
                   yyextra->fileContext.empty() ? "" : " in file ",
                   yyextra->fileContext.empty() ? "" :
                   yyextra->fileContext.c_str());
           (*yylval_param) = TfStringToDouble(yytext);
        }
        return TOK_NUMBER;
    }

    /* Numbers with decimal places or exponents: store as double. */
-?[[:digit:]]+(\.[[:digit:]]*)?([eE][+\-]?[[:digit:]]+)?   |
-?\.[[:digit:]]+([eE][+\-]?[[:digit:]]+)? {
        (*yylval_param) = TfStringToDouble(yytext);
        return TOK_NUMBER;
    }

    /* regexps for negative infinity.  we don't handle inf and nan here
     * because they look like identifiers.  we handle them in parser where
     * we have the additional context we need to distinguish them from
     * identifiers. */
-inf {
        (*yylval_param) = -std::numeric_limits<double>::infinity();
        return TOK_NUMBER;
    }

    /* various single-character punctuation.  return the character
     * itself as the token.
     */
[=,:;\$\.\[\]\(\){}&@-] {
        return yytext[0];
    }

    /* the default rule is to ECHO any unmatched character.  by returning a
     * token that the parser does not know how to handle these become syntax
     * errors instead.
     */
<*>.|\\n {
        return TOK_SYNTAX_ERROR;
    }

%%
