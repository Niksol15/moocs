/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%option noyywrap

%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;
//int yy_top_state();

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

static void add_char(const char ch);

namespace {
    char msg_unmatched_comment_closing[] = "Unmatched *)";
    char msg_unfinished_comment[] = "EOF in comment";
    char msg_string_too_long[] = "String constant too long";
    char msg_str_contains_null_char[] = "String contains null character";
    char msg_eof_in_str[] = "EOF in string constant";
    char msg_str_unexpected_newline[] = "Unterminated string constant";
    char* msg_str_error = nullptr;
    int comment_nesting = 0;
}

%}

/*
 * Define names for regular expressions here.
 */

DARROW      =>
ASSIGN      <-
LE          <=

INT_CONST   [0-9]+

/* Keywords: */
TRUE        t(?i:rue)
FALSE       f(?i:alse)
CLASS       (?i:class)
ELSE        (?i:else)
FI          (?i:fi)
IF          (?i:if)
IN          (?i:in)
INHERITS    (?i:inherits)
LET         (?i:let)
LOOP        (?i:loop)
POOL        (?i:pool)
THEN        (?i:then)
WHILE       (?i:while)
CASE        (?i:case)
ESAC        (?i:esac)
OF          (?i:of)
NEW         (?i:new)
NOT         (?i:not)
ISVOID      (?i:isvoid)

ID          [_0-9a-zA-Z]*
TYPEID      [A-Z]{ID}
OBJECTID    [a-z]{ID}

%x COMMENT_COND ONE_LINE_COMMENT_COND
%x STR_CONST_COND
%x BAD_STR_COND

%%

 /* Singe character operators*/
"." {
    return (int)'.';
}

"@" {
    return (int)'@';
}

"~" {
    return (int)'~';
}

"*" {
    return (int)'*';
}

"/" {
    return (int)'/';
}

"+" {
    return (int)'+';
}

"-" {
    return (int)'-';
}

"<" {
    return (int)'<';
}

"=" {
    return (int)'=';
}

"{" {
    return (int)'{';
}

"}" {
    return (int)'}';
}

"(" {
    return (int)'(';
}

")" {
    return (int)')';
}

":" {
    return (int)':';
}

";" {
    return (int)';';
}

"," {
    return (int)',';
}

 /* One line comment */
"--" {
    BEGIN(ONE_LINE_COMMENT_COND);
}

<ONE_LINE_COMMENT_COND>"\n" {
    BEGIN(INITIAL);
    curr_lineno++;
}

<ONE_LINE_COMMENT_COND><<EOF>> {
    BEGIN(INITIAL);
}

<ONE_LINE_COMMENT_COND>.

 /*
  *  Nested comments
  */

"(*" {
    BEGIN(COMMENT_COND);
    ++comment_nesting;
}

<COMMENT_COND>"(*" {
    ++comment_nesting;
}

<COMMENT_COND><<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = msg_unfinished_comment;
    return (ERROR);
}

<COMMENT_COND>"\n" {
    curr_lineno++;
}

<COMMENT_COND>"*)" {
    if(--comment_nesting == 0){
        BEGIN(INITIAL);
    }
}

<COMMENT_COND>.

"*)" {
    cool_yylval.error_msg = msg_unmatched_comment_closing;
    return (ERROR);
}


 /*
  *  The multiple-character operators.
  */
{DARROW} {
    return (DARROW);
}

{ASSIGN} {
    return (ASSIGN);
}

{LE} {
    return (LE);
}

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

{TRUE} {
    cool_yylval.boolean = true;
    return (BOOL_CONST);
}

{FALSE} {
    cool_yylval.boolean = false;
    return (BOOL_CONST);
}

{CLASS} {
    return (CLASS);
}

{ELSE} {
    return (ELSE);
}

{FI} {
    return (FI);
}

{IF} {
    return (IF);
}

{IN} {
    return (IN);
}

{INHERITS} {
    return (INHERITS);
}

{LET} {
    return (LET);
}

{LOOP} {
    return (LOOP);
}

{POOL} {
    return (POOL);
}

{THEN} {
    return (THEN);
}

{WHILE} {
    return (WHILE);
}

{CASE} {
    return (CASE);
}

{ESAC} {
    return (ESAC);
}

{OF} {
    return (OF);
}

{NEW} {
    return (NEW);
}

{NOT} {
    return (NOT);
}

{ISVOID} {
    return (ISVOID);
}

 /* Ids: */
{OBJECTID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return (OBJECTID);
}

{TYPEID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return (TYPEID);
}

 /* Int constants */
{INT_CONST} {
    cool_yylval.symbol = inttable.add_string(yytext);
    return (INT_CONST);
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */

"\"" {
    BEGIN(STR_CONST_COND);
    memset(string_buf, 0, MAX_STR_CONST);
    string_buf_ptr = string_buf;
}

<STR_CONST_COND>"\"" {
    BEGIN(INITIAL);
    cool_yylval.symbol = stringtable.add_string(string_buf);
    return (STR_CONST);
}

<STR_CONST_COND>"\\\n" {
    add_char('\n');
    curr_lineno++;
}

<STR_CONST_COND>"\\". {
    char ch = yytext[1];
    switch(ch){
        case 't':
            add_char('\t');
            break;
        case 'b':
            add_char('\b');
            break;
        case 'f':
            add_char('\f');
            break;
        case 'n':
            add_char('\n');
            break;
        case '\0':
            BEGIN(BAD_STR_COND);
            msg_str_error = msg_str_contains_null_char;
        default:
            add_char(ch);
        break;
    }
}

<STR_CONST_COND>"\n" {
    BEGIN(INITIAL);
    curr_lineno++;
    cool_yylval.error_msg = msg_str_unexpected_newline;
    return (ERROR);
}

<STR_CONST_COND>"\0" {
    BEGIN(BAD_STR_COND);
    msg_str_error = msg_str_contains_null_char;
}

<STR_CONST_COND><<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = msg_eof_in_str;
    return (ERROR);
}

<STR_CONST_COND>. {
    add_char(yytext[0]);
}

<BAD_STR_COND>"\""|"\n" {
    BEGIN(INITIAL);
    cool_yylval.error_msg = msg_str_error;
    return (ERROR);
}

<BAD_STR_COND><<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = msg_str_error;
    return (ERROR);
}

<BAD_STR_COND>.

 /* Handle new line*/
"\n" {
    curr_lineno++;
}

 /* Skip whitespaces, the set may not be exhaustive*/
[ \f\r\t\v]+

 /* Anything else is considered an error*/
. {
    cool_yylval.error_msg = yytext;
    return (ERROR);
}

%%

static void add_char(const char ch) {
    if (YYSTATE == BAD_STR_COND) {
        return;
    }
    if(string_buf_ptr - string_buf == MAX_STR_CONST - 1 ) {
        BEGIN(BAD_STR_COND);
        msg_str_error = msg_string_too_long;
        return;
    }
    *string_buf_ptr = ch;
    ++string_buf_ptr;
}