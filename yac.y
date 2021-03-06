%{ 
#include <stdio.h> 
#include <stdlib.h> 
#include <stdarg.h> 
#include "ex.h" 

/* prototypes */ 
nodeType *opr(int oper, DataTyprEnum tp, int nops, ...); 
nodeType *id(int i);    /* identifiers */
nodeType *con(float value, DataTyprEnum tp);   /* imidiate value */

DataTyprEnum dt_of_children(nodeType *p1, nodeType *p2);
DataTyprEnum dt_of_node(nodeType *p);

void freeNode(nodeType *p); 
int ex(nodeType *p); 
int yylex(void); 
int yylineno;
int yyerrorno;
int yywarn_no;

FILE* output;
FILE* warn_file;
%}

%union { 
    int iValue;                 /* integer value */ 
    float fValue ;                 /*  float value*/
    int bValue;                 /* bool value */
    char sIndex;                /* symbol table index */
    nodeType *nPtr;             /* node pointer */ 
}; 


%token  NUMBER FNUMBER CHAR BOOL CONST

%token CASE DEFAULT IF THEN ELSEIF ELSE SWITCH WHILE REPEAT UNTIL FOR GOTO CONTINUE BREAK RETURN
%token READ PRINT EXIT CASES

////////////////////////////////////////////////////

%token <iValue> VALUE 
%token <fValue> FVALUE
%token <bValue> BVALUE
%token <iValue> CVALUE
%token <sIndex> VARIABLE 

%right '='
%left OR_OR
%left AND_AND
%left OR
%left XOR
%left AND
%nonassoc EQ NE
%left  GE LE  '>' '<'
%left '+' '-' 
%left '*' '/' '%' 
%left NOT L_NOT

%nonassoc IFX
%nonassoc ELSE
%nonassoc UMINUS 
%type <nPtr> stmt expr stmt_list assign_stmt def_stmt scop_stmt case_stmts one_value switch_stmt default_stmt case_stmt
%% 

program: 
            code                { exit(0); } 
            ; 

code: 
        code stmt         { ex($2); freeNode($2); } 
        | code error ';'  {yyerrok;}
        | /* NULL */ 
  ; 


stmt: 
                ';'                     { $$ = opr(';',IntType, 2, NULL, NULL); } 
              | assign_stmt ';'         {$$ = $1; printf("\n"); }
              | def_stmt ';'         {$$ = $1; printf("\n");}
              | scop_stmt         {$$ = $1; printf("\n");}

              | case_stmts  {$$ = $1;}
              | PRINT expr ';'          { $$ = opr(PRINT, IntType,  1, $2); printf("\n");} 
                ; 

assign_stmt:
            VARIABLE '=' expr    { $$ = opr('=', dt_of_node($3), 2, id($1), $3); }
            ;


def_stmt:
                NUMBER VARIABLE      {$$ = opr(NUMBER, IntType, 1,  id($2)); }
              | FNUMBER VARIABLE      {$$ = opr(FNUMBER, FloatType, 1,  id($2)); }
              | CHAR VARIABLE        {$$ = opr(CHAR, IntType, 1, id($2)); }
              | BOOL VARIABLE        {$$ = opr(BOOL, IntType, 1, id($2)); }

              | CONST NUMBER assign_stmt        {$$ = opr(CONST, IntType, 2,  id(1), $3); }
              | CONST FNUMBER assign_stmt        {$$ = opr(CONST, FloatType, 2, id(2), $3); }
              | CONST CHAR assign_stmt        {$$ = opr(CONST, CharType, 2, id(3), $3); }
              | CONST BOOL assign_stmt        {$$ = opr(CONST, BoolType, 2, id(4), $3); }
            ;


scop_stmt:
            WHILE '(' expr ')' stmt { $$ = opr(WHILE, IntType, 2, $3, $5); } 
              | REPEAT stmt UNTIL '(' expr ')' ';' { $$ = opr(REPEAT, IntType, 2, $2, $5); }
              | FOR '(' assign_stmt ';' expr ';' assign_stmt ')'  stmt { $$ = opr(FOR, IntType, 4, $3, $5, $7, $9); } 
              | IF '(' expr ')' stmt %prec IFX { $$ = opr(IF, IntType, 2, $3, $5); } 
              | IF '(' expr ')' stmt ELSE stmt 
                                        { $$ = opr(IF, IntType, 3, $3, $5, $7); } 
              | switch_stmt     {$$ = $1;}
              | '{' stmt_list '}'       { $$ = $2; } 
            ;


stmt_list: 
                stmt                  { $$ = $1; } 
              | stmt_list stmt        { $$ = opr(';', dt_of_children($1, $2), 2, $1, $2); } 
              ; 

switch_stmt:
               SWITCH '(' one_value ')'  '{' case_stmts default_stmt'}'            { $$ = opr(SWITCH, dt_of_node($3), 3, $3, $6, $7); } 
               | SWITCH '(' one_value ')'  '{' case_stmts '}'            { $$ = opr(SWITCH, dt_of_node($3), 2, $3, $6); } 
              ; 

case_stmt:
                CASE one_value ':' stmt                  { $$ = opr(CASE, dt_of_children($2, $4), 2, $2, $4); }
                ;

case_stmts: 
                case_stmt                  { $$ = $1;} 
              | case_stmts case_stmt         { $$ = opr(CASES, dt_of_children($1, $2), 2, $1, $2); } 
              ; 

default_stmt: 
                DEFAULT  ':' stmt                  { $$ = opr(DEFAULT, dt_of_node($3), 1,  $3); } 
            ; 

one_value: 
                VALUE               { $$ = con($1, IntType); }
              | FVALUE              {$$ = con($1, FloatType);}
              | BVALUE              {$$ = con($1, BoolType);}
              | CVALUE              {$$ = con($1, CharType);}
              | VARIABLE              {
                        /* searh for the type of the variable  */
                        // printf("yac");
                         $$ = id($1);
                        }
            ;

expr: 
            one_value   {$$ = $1;}
              | expr '+' expr         { $$ = opr('+', dt_of_children($1, $3), 2, $1, $3); } 
              | expr '-' expr         { $$ = opr('-', dt_of_children($1, $3), 2, $1, $3); } 
              | expr '*' expr         { $$ = opr('*',  dt_of_children($1, $3), 2, $1, $3); } 
              | expr '/' expr         { $$ = opr('/',  dt_of_children($1, $3),  2, $1, $3); } 
              | expr '%' expr         { $$ = opr('%',  dt_of_children($1, $3),  2, $1, $3); } 
              | expr '<' expr         { $$ = opr('<',  dt_of_children($1, $3), 2, $1, $3); } 
              | expr '>' expr         { $$ = opr('>',  dt_of_children($1, $3), 2, $1, $3); } 
              | expr GE expr          { $$ = opr(GE, dt_of_children($1, $3), 2, $1, $3); } 
              | expr LE expr          { $$ = opr(LE, dt_of_children($1, $3), 2, $1, $3); } 
              | expr NE expr          { $$ = opr(NE, dt_of_children($1, $3), 2, $1, $3); } 
              | expr EQ expr          { $$ = opr(EQ, dt_of_children($1, $3), 2, $1, $3); } 
              
              | expr AND_AND expr       {$$ = opr(AND_AND, dt_of_children($1, $3), 2, $1, $3); }
              | expr OR_OR expr       {$$ = opr(OR_OR, dt_of_children($1, $3), 2, $1, $3); }
              | NOT expr       {$$ = opr(NOT, dt_of_node($2), 1 , $2); }

              | expr AND expr       {$$ = opr(AND, dt_of_children($1, $3), 2, $1, $3); }
              | expr OR expr       {$$ = opr(OR, dt_of_children($1, $3), 2, $1, $3); }
              | expr XOR expr       {$$ = opr(XOR, dt_of_children($1, $3), 2, $1, $3); }
              | L_NOT expr       {$$ = opr(L_NOT, dt_of_node($2), 1, $2); }
              
              | '(' expr ')'          { $$ = $2; } 
              ; 
%% 

#define SIZEOF_NODETYPE ((char *)&p->con - (char *)p) 

nodeType *con(float value, DataTyprEnum dt) { 
    nodeType *p; 
    size_t nodeSize; 
    /* allocate node */ 
    nodeSize = SIZEOF_NODETYPE + sizeof(conNodeType); 
    if ((p = malloc(nodeSize)) == NULL) 
        yyerror("out of memory"); 
    /* copy information */ 
    p->type = typeCon; 
    p->dt = dt;
    if(dt == FloatType)
        p->con.fvalue = value;
    else 
        p->con.value = (int)value;        
    return p; 
} 

nodeType *id(int i) { 
    nodeType *p; 
    size_t nodeSize; 
    /* allocate node */ 
    nodeSize = SIZEOF_NODETYPE + sizeof(idNodeType); 
    if ((p = malloc(nodeSize)) == NULL) 
        yyerror("out of memory"); 
    /* copy information */ 
    p->type = typeId; 
//    p->dt = dt;
    p->id.i = i; 
    return p; 
} 

nodeType *opr(int oper, DataTyprEnum dt, int nops, ...) { 
    va_list ap; 
    nodeType *p; 
    size_t nodeSize; 
    int i; 
    /* allocate node */ 
    nodeSize = SIZEOF_NODETYPE + sizeof(oprNodeType) + 
        (nops - 1) * sizeof(nodeType*); 
    if ((p = malloc(nodeSize)) == NULL) 
        yyerror("out of memory"); 
    /* copy information */ 
    p->type = typeOpr;
    p->dt = dt;
    p->opr.oper = oper; 
    p->opr.nops = nops; 
    va_start(ap, nops); 
    for (i = 0; i < nops; i++) 
        p->opr.op[i] = va_arg(ap, nodeType*);
    va_end(ap); 
    return p; 
} 

void freeNode(nodeType *p) { 
    int i; 
    if (!p) return; 
    if (p->type == typeOpr) { 
        for (i = 0; i < p->opr.nops; i++) 
            freeNode(p->opr.op[i]); 
    } 
    free (p); 
} 



int main(void) { 
    
    output = fopen ("errors.txt","w");
    warn_file = fopen ("warning.txt","w");
    sym_count = yyerrorno = yywarn_no = 0;
    int status = yyparse(); 
    fclose(output);
    fclose(warn_file);
    if (status)
      return status;
    if (yynerrs)
      return 3;
    return 0; 
} 

void yyerror(char *s) { 
    yyerrorno++;
    fprintf(output, "error #%d - line #%d: %s\n",yyerrorno, yylineno, s);
    // fprintf(stderr, "error #%d - line #%d: %s\n",yyerrorno, yylineno, s);
} 

void yywarning(char *s) { 
    yywarn_no++;
    fprintf(warn_file, "Warning #%d - line #%d: %s\n",yywarn_no, yylineno, s);
    // fprintf(stderr, "Warning #%d - line #%d: %s\n",yywarn_no, yylineno, s);
} 
