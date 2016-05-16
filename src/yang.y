/**
 * @file yang.y
 * @author Pavol Vican
 * @brief YANG parser for libyang (bison grammar)
 *
 * Copyright (c) 2015 CESNET, z.s.p.o.
 *
 * This source code is licensed under BSD 3-Clause License (the "License").
 * You may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://opensource.org/licenses/BSD-3-Clause
 */

%define api.pure full
%locations

%parse-param {void *scanner}
%parse-param {struct lys_module *module}
%parse-param {struct lys_submodule *submodule}
%parse-param {struct unres_schema *unres}
%parse-param {struct lys_array_size *size_arrays}
%parse-param {int read_all}

%lex-param {void *scanner}

%{
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>
#include "context.h"
#include "resolve.h"
#include "common.h"
#include "parser_yang.h"
#include "parser_yang_lex.h"
#include "parser.h"

/* only syntax rules */
#define EXTENSION_ARG 0x01
#define EXTENSION_STA 0x02
#define EXTENSION_DSC 0x04
#define EXTENSION_REF 0x08
#define DISABLE_INHERIT 0
#define ENABLE_INHERIT 0x01

void yyerror(YYLTYPE *yylloc, void *scanner, ...);
char *s, *tmp_s;
char rev[LY_REV_SIZE];
struct lys_module *trg;
struct lys_node *tpdf_parent;
/* temporary pointer for the check extension nacm */
struct lys_node *data_node;
/* pointer on the current parsed element*/
void *actual;
int config_inherit;
int actual_type;
int64_t cnt_val;
%}

%union {
  int32_t i;
  uint32_t uint;
  char *str;
  void *v;
  struct lys_module *inc;
  struct yang_type *type;
  union {
    uint32_t index;
    struct lys_node_container *container;
    struct lys_node_anyxml *anyxml;
    struct type_choice choice;
    struct type_node node;
    struct lys_node_case *cs;
    struct lys_node_grp *grouping;
    struct type_uses uses;
    struct lys_refine *refine;
    struct lys_node_notif *notif;
    struct type_deviation *deviation;
  } nodes;
}

%token UNION_KEYWORD
%token ANYXML_KEYWORD
%token WHITESPACE
%token ERROR
%token EOL
%token STRING
%token STRINGS
%token IDENTIFIER
%token IDENTIFIERPREFIX
%token REVISION_DATE
%token TAB
%token DOUBLEDOT
%token URI
%token INTEGER
%token NON_NEGATIVE_INTEGER
%token ZERO
%token DECIMAL
%token ARGUMENT_KEYWORD
%token AUGMENT_KEYWORD
%token BASE_KEYWORD
%token BELONGS_TO_KEYWORD
%token BIT_KEYWORD
%token CASE_KEYWORD
%token CHOICE_KEYWORD
%token CONFIG_KEYWORD
%token CONTACT_KEYWORD
%token CONTAINER_KEYWORD
%token DEFAULT_KEYWORD
%token DESCRIPTION_KEYWORD
%token ENUM_KEYWORD
%token ERROR_APP_TAG_KEYWORD
%token ERROR_MESSAGE_KEYWORD
%token EXTENSION_KEYWORD
%token DEVIATION_KEYWORD
%token DEVIATE_KEYWORD
%token FEATURE_KEYWORD
%token FRACTION_DIGITS_KEYWORD
%token GROUPING_KEYWORD
%token IDENTITY_KEYWORD
%token IF_FEATURE_KEYWORD
%token IMPORT_KEYWORD
%token INCLUDE_KEYWORD
%token INPUT_KEYWORD
%token KEY_KEYWORD
%token LEAF_KEYWORD
%token LEAF_LIST_KEYWORD
%token LENGTH_KEYWORD
%token LIST_KEYWORD
%token MANDATORY_KEYWORD
%token MAX_ELEMENTS_KEYWORD
%token MIN_ELEMENTS_KEYWORD
%token MODULE_KEYWORD
%token MUST_KEYWORD
%token NAMESPACE_KEYWORD
%token NOTIFICATION_KEYWORD
%token ORDERED_BY_KEYWORD
%token ORGANIZATION_KEYWORD
%token OUTPUT_KEYWORD
%token PATH_KEYWORD
%token PATTERN_KEYWORD
%token POSITION_KEYWORD
%token PREFIX_KEYWORD
%token PRESENCE_KEYWORD
%token RANGE_KEYWORD
%token REFERENCE_KEYWORD
%token REFINE_KEYWORD
%token REQUIRE_INSTANCE_KEYWORD
%token REVISION_KEYWORD
%token REVISION_DATE_KEYWORD
%token RPC_KEYWORD
%token STATUS_KEYWORD
%token SUBMODULE_KEYWORD
%token TYPE_KEYWORD
%token TYPEDEF_KEYWORD
%token UNIQUE_KEYWORD
%token UNITS_KEYWORD
%token USES_KEYWORD
%token VALUE_KEYWORD
%token WHEN_KEYWORD
%token YANG_VERSION_KEYWORD
%token YIN_ELEMENT_KEYWORD
%token ADD_KEYWORD
%token CURRENT_KEYWORD
%token DELETE_KEYWORD
%token DEPRECATED_KEYWORD
%token FALSE_KEYWORD
%token NOT_SUPPORTED_KEYWORD
%token OBSOLETE_KEYWORD
%token REPLACE_KEYWORD
%token SYSTEM_KEYWORD
%token TRUE_KEYWORD
%token UNBOUNDED_KEYWORD
%token USER_KEYWORD

%type <uint> positive_integer_value
%type <uint> non_negative_integer_value
%type <uint> max_value_arg_str
%type <uint> max_elements_stmt
%type <uint> min_value_arg_str
%type <uint> min_elements_stmt
%type <uint> decimal_string_restrictions
%type <uint> fraction_digits_arg_str
%type <uint> position_value_arg_str
%type <uint> extension_opt_stmt
%type <i> module_header_stmts
%type <i> submodule_header_stmts
%type <str> tmp_identifier_arg_str
%type <str> message_opt_stmt
%type <str> identity_opt_stmt
%type <i> status_stmt
%type <i> status_read_stmt
%type <i> status_arg_str
%type <i> config_stmt
%type <i> config_read_stmt
%type <i> config_arg_str
%type <i> mandatory_stmt
%type <i> mandatory_read_stmt
%type <i> mandatory_arg_str
%type <i> ordered_by_stmt
%type <i> ordered_by_arg_str
%type <i> integer_value_arg_str
%type <i> integer_value
%type <i> feature_opt_stmt
%type <v> length_arg_str
%type <v> pattern_arg_str
%type <v> range_arg_str
%type <v> enum_arg_str
%type <v> bit_arg_str
%type <v> union_spec
%type <v> typedef_arg_str
%type <type> type_stmtsep
%type <nodes> container_opt_stmt
%type <nodes> anyxml_opt_stmt
%type <nodes> choice_opt_stmt
%type <nodes> case_opt_stmt
%type <nodes> grouping_opt_stmt
%type <nodes> leaf_opt_stmt
%type <nodes> leaf_list_opt_stmt
%type <nodes> list_opt_stmt
%type <nodes> type_opt_stmt
%type <nodes> uses_opt_stmt
%type <nodes> refine_body_opt_stmts
%type <nodes> augment_opt_stmt
%type <nodes> rpc_opt_stmt
%type <nodes> input_output_opt_stmt
%type <nodes> notification_opt_stmt
%type <nodes> deviation_opt_stmt
%type <nodes> deviate_add_opt_stmt
%type <nodes> deviate_delete_opt_stmt
%type <nodes> deviate_replace_opt_stmt
%type <inc> include_stmt
%type <inc> import_stmt

%destructor { free($$); } tmp_identifier_arg_str
%destructor { if (read_all && $$.choice.s) { free($$.choice.s); } } choice_opt_stmt
%destructor { if (read_all) {
                free($$.deviation);
              }
            } deviation_opt_stmt
%destructor { if (read_all) {
                yang_delete_type(module, $$);
              }
            } type_stmtsep

%%

/* to simplify code, store the module/submodule being processed as trg */

start: module_stmt
 |  submodule_stmt { if (read_all && lyp_propagate_submodule(module, submodule)) {
                       YYABORT;
                     }
                   }


string_1: STRING  { if (read_all) {
                      if (yyget_text(scanner)[0] == '"') {
                        s = yang_read_string(yyget_text(scanner) + 1, yyget_leng(scanner) - 2, yylloc.first_column);
                        if (!s) {
                          YYABORT;
                        }
                      } else {
                        s = calloc(1, yyget_leng(scanner) - 1);
                        if (!s) {
                          LOGMEM;
                          YYABORT;
                        }
                        memcpy(s, yyget_text(scanner) + 1, yyget_leng(scanner) - 2);
                      }
                    }
                  }
optsep string_2


string_2: %empty
  |  string_2 '+' optsep
     STRING { if (read_all){
                char *temp;
                if (yyget_text(scanner)[0] == '"') {
                  temp = yang_read_string(yyget_text(scanner) + 1, yyget_leng(scanner) - 2, yylloc.first_column);
                  if (!temp) {
                    YYABORT;
                  }
                  s = ly_realloc(s, strlen(temp) + strlen(s) + 1);
                  if (s) {
                    strcat(s, temp);
                    free(temp);
                  } else {
                    free(temp);
                    LOGMEM;
                    YYABORT;
                  }
                } else {
                  int length = yyget_leng(scanner) - 2 + strlen(s) + 1;
                  s = ly_realloc(s, length);
                  if (s) {
                    memcpy(s + strlen(s), yyget_text(scanner) + 1, yyget_leng(scanner) - 2);
                    s[length - 1] = '\0';
                  } else {
                    LOGMEM;
                    YYABORT;
                  }
                }
              }
            }
     optsep;

module_stmt: optsep MODULE_KEYWORD sep identifier_arg_str { if (read_all) {
                                                              if (submodule) {
                                                                free(s);
                                                                LOGVAL(LYE_INSTMT, LY_VLOG_NONE, NULL, "module");
                                                                YYABORT;
                                                              }
                                                              trg = module;
                                                              yang_read_common(trg,s,MODULE_KEYWORD);
                                                              s = NULL;
                                                              config_inherit = ENABLE_INHERIT;
                                                            }
                                                          }
             '{' stmtsep
                 module_header_stmts { if (read_all && !module->ns) { LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "namespace", "module"); YYABORT; }
                                       if (read_all && !module->prefix) { LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "prefix", "module"); YYABORT; }
                                     }
                 linkage_stmts
                 meta_stmts
                 revision_stmts
                 body_stmts
             '}' optsep

module_header_stmts: %empty  { $$ = 0; }
  |  module_header_stmts yang_version_stmt { if ($1) { LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "yang version", "module"); YYABORT; } $$ = 1; }
  |  module_header_stmts namespace_stmt { if (read_all && yang_read_common(module, s, NAMESPACE_KEYWORD)) {YYABORT;} s=NULL; }
  |  module_header_stmts prefix_stmt { if (read_all && yang_read_prefix(module, NULL, s, MODULE_KEYWORD)) {YYABORT;} s=NULL; }
  ;

submodule_stmt: optsep SUBMODULE_KEYWORD sep identifier_arg_str { if (read_all) {
                                                                    if (!submodule) {
                                                                      free(s);
                                                                      LOGVAL(LYE_INSTMT, LY_VLOG_NONE, NULL, "submodule");
                                                                      YYABORT;
                                                                    }
                                                                    trg = (struct lys_module *)submodule;
                                                                    yang_read_common(trg,s,MODULE_KEYWORD);
                                                                    s = NULL;
                                                                    config_inherit = ENABLE_INHERIT;
                                                                  }
                                                                }
                '{' stmtsep
                    submodule_header_stmts  { if (read_all && !submodule->prefix) {
                                                LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "belongs-to", "submodule");
                                                YYABORT;
                                              }
                                            }
                    linkage_stmts
                    meta_stmts
                    revision_stmts
                    body_stmts
                '}' optsep

submodule_header_stmts: %empty { $$ = 0; }
  |  submodule_header_stmts yang_version_stmt { if ($1) {
                                                  LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "yang version", "submodule");
                                                  YYABORT;
                                                }
                                                $$ = 1;
                                              }
  |  submodule_header_stmts { if (read_all) {
                                if (submodule->prefix) {
                                  LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "belongs-to", "submodule");
                                  YYABORT;
                                }
                              }
                            }
     belongs_to_stmt

yang_version_stmt: YANG_VERSION_KEYWORD sep yang_version_arg_str stmtend;

yang_version_arg_str: NON_NEGATIVE_INTEGER { if (strlen(yyget_text(scanner))!=1 || yyget_text(scanner)[0]!='1') {
                                               YYABORT;
                                             }
                                           } optsep
  | string_1 { if (read_all) {
                 if (strlen(s)!=1 || s[0]!='1') {
                   free(s);
                   YYABORT;
                 }
               }
             }

namespace_stmt: NAMESPACE_KEYWORD sep string stmtend;

linkage_stmts: %empty { if (read_all) {
                          if (size_arrays->imp) {
                            trg->imp = calloc(size_arrays->imp, sizeof *trg->imp);
                            if (!trg->imp) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                          if (size_arrays->inc) {
                            trg->inc = calloc(size_arrays->inc, sizeof *trg->inc);
                            if (!trg->inc) {
                              LOGMEM;
                              YYABORT;
                            }
                            trg->inc_size = size_arrays->inc;
                            size_arrays->inc = 0;
                            /* trg->inc_size can be updated by the included submodules,
                             * so we will use size_arrays->inc here, trg->inc_size stores the
                             * target size of the array
                             */
                          }
                        }
                      }
 |  linkage_stmts import_stmt
 |  linkage_stmts include_stmt
 ;

import_stmt: IMPORT_KEYWORD sep tmp_identifier_arg_str {
                 if (!read_all) {
                   size_arrays->imp++;
                 } else {
                   actual = &trg->imp[trg->imp_size];
                 }
             }
             '{' stmtsep
                 prefix_stmt { if (read_all) {
                                 if (yang_read_prefix(trg, actual, s, IMPORT_KEYWORD)) {YYABORT;}
                                 s=NULL;
                                 actual_type=IMPORT_KEYWORD;
                               }
                             }
                 revision_date_opt
             '}' stmtsep { if (read_all) {
                             $$ = trg;
                             if (yang_fill_import(trg, actual, $3)) {
                               YYABORT;
                             }
                             trg = $$;
                             config_inherit = ENABLE_INHERIT;
                           }
                         }

tmp_identifier_arg_str: identifier_arg_str { $$ = s; s = NULL; }

include_stmt: INCLUDE_KEYWORD sep tmp_identifier_arg_str { if (read_all) {
                                                             memset(rev, 0, LY_REV_SIZE);
                                                             actual_type = INCLUDE_KEYWORD;
                                                           }
                                                           else {
                                                             size_arrays->inc++;
                                                           }
                                                         }
              include_end stmtsep { if (read_all) {
                                      $$ = trg;
                                      if (yang_fill_include(module, submodule, $3, rev, size_arrays->inc, unres)) {
                                        YYABORT;
                                      }
                                      size_arrays->inc++;
                                      s = NULL;
                                      trg = $$;
                                      config_inherit = ENABLE_INHERIT;
                                    }
                                  }

include_end: ';'
  | '{' stmtsep
     revision_date_opt
    '}'

revision_date_opt: %empty
  | revision_date_stmt;

revision_date_stmt: REVISION_DATE_KEYWORD sep date_arg_str
                    stmtend { if (read_all) {
                                 if (actual_type==IMPORT_KEYWORD) {
                                     memcpy(((struct lys_import *)actual)->rev, s, LY_REV_SIZE-1);
                                 } else {                              // INCLUDE KEYWORD
                                     memcpy(rev, s, LY_REV_SIZE - 1);
                                 }
                                 free(s);
                                 s = NULL;
                               }
                             }

belongs_to_stmt: BELONGS_TO_KEYWORD sep identifier_arg_str { if (read_all) {
                                                               if (!ly_strequal(s, submodule->belongsto->name, 0)) {
                                                                 LOGVAL(LYE_INARG, LY_VLOG_NONE, NULL, s, "belongs-to");
                                                                 free(s);
                                                                 YYABORT;
                                                               }
                                                               free(s);
                                                               s = NULL;
                                                             }
                                                           }
                 '{' stmtsep
                     prefix_stmt { if (read_all) {
                                     if (yang_read_prefix(trg, NULL, s, MODULE_KEYWORD)) {
                                       YYABORT;
                                     }
                                     s = NULL;
                                   }
                                 }
                 '}' stmtsep

prefix_stmt: PREFIX_KEYWORD sep prefix_arg_str stmtend;

meta_stmts: %empty
  |  meta_stmts organization_stmt { if (read_all && yang_read_common(trg, s, ORGANIZATION_KEYWORD)) {YYABORT;} s=NULL; }
  |  meta_stmts contact_stmt { if (read_all && yang_read_common(trg, s, CONTACT_KEYWORD)) {YYABORT;} s=NULL; }
  |  meta_stmts description_stmt { if (read_all && yang_read_description(trg, NULL, s, NULL)) {
                                     YYABORT;
                                   }
                                   s = NULL;
                                 }
  |  meta_stmts reference_stmt { if (read_all && yang_read_reference(trg, NULL, s, NULL)) {
                                   YYABORT;
                                 }
                                 s=NULL;
                               }

organization_stmt: ORGANIZATION_KEYWORD sep string stmtend;

contact_stmt: CONTACT_KEYWORD sep string stmtend;

description_stmt: DESCRIPTION_KEYWORD sep string stmtend;

reference_stmt: REFERENCE_KEYWORD sep string stmtend;

revision_stmts: %empty { if (read_all && size_arrays->rev) {
                           trg->rev = calloc(size_arrays->rev, sizeof *trg->rev);
                           if (!trg->rev) {
                             LOGMEM;
                             YYABORT;
                           }
                         }
                       }
  | revision_stmts revision_stmt stmtsep;


revision_stmt: REVISION_KEYWORD sep date_arg_str { if (read_all) {
                                                     if(!(actual=yang_read_revision(trg,s))) {YYABORT;}
                                                     s=NULL;
                                                   } else {
                                                     size_arrays->rev++;
                                                   }
                                                 }
               revision_end;

revision_end: ';'
  | '{' stmtsep { actual_type = REVISION_KEYWORD; }
        revision_opt_stmt
     '}'
  ;

revision_opt_stmt: %empty
  |  revision_opt_stmt description_stmt { if (read_all && yang_read_description(trg, actual, s, "revision")) {
                                            YYABORT;
                                          }
                                          s = NULL;
                                        }
  |  revision_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, actual, s, "revision")) {
                                          YYABORT;
                                        }
                                        s = NULL;
                                      }
  ;

date_arg_str: REVISION_DATE { if (read_all) {
                                s = strdup(yyget_text(scanner));
                                if (!s) {
                                  LOGMEM;
                                  YYABORT;
                                }
                              }
                            }
              optsep
  | string_1 { if (read_all && lyp_check_date(s)) {
                   free(s);
                   YYABORT;
               }
             }

body_stmts: %empty { if (read_all) {
                       if (size_arrays->features) {
                         trg->features = calloc(size_arrays->features,sizeof *trg->features);
                         if (!trg->features) {
                           LOGMEM;
                           YYABORT;
                         }
                       }
                       if (size_arrays->ident) {
                         trg->ident = calloc(size_arrays->ident,sizeof *trg->ident);
                         if (!trg->ident) {
                           LOGMEM;
                           YYABORT;
                         }
                       }
                       if (size_arrays->augment) {
                         trg->augment = calloc(size_arrays->augment,sizeof *trg->augment);
                         if (!trg->augment) {
                           LOGMEM;
                           YYABORT;
                         }
                       }
                       if (size_arrays->tpdf) {
                         trg->tpdf = calloc(size_arrays->tpdf, sizeof *trg->tpdf);
                         if (!trg->tpdf) {
                           LOGMEM;
                           YYABORT;
                         }
                       }
                       if (size_arrays->deviation) {
                         trg->deviation = calloc(size_arrays->deviation, sizeof *trg->deviation);
                         if (!trg->deviation) {
                           LOGMEM;
                           YYABORT;
                         }
                         /* module with deviation - must be implemented (description of /ietf-yang-library:modules-state/module/deviation) */
                         module->implemented = 1;
                       }
                       actual = NULL;
                     }
                   }
  | body_stmts body_stmt stmtsep { actual = NULL; }


body_stmt: extension_stmt
  | feature_stmt
  | identity_stmt
  | typedef_stmt { if (!read_all) { size_arrays->tpdf++; } }
  | grouping_stmt
  | data_def_stmt
  | augment_stmt { if (!read_all) {
                     size_arrays->augment++;
                   } else {
                     config_inherit = ENABLE_INHERIT;
                   }
                 }
  | rpc_stmt
  | notification_stmt
  | deviation_stmt { if (!read_all) { size_arrays->deviation++; } }

extension_stmt: EXTENSION_KEYWORD sep identifier_arg_str { if (read_all) {
                                                             /* we have the following supported (hardcoded) extensions: */
                                                             /* ietf-netconf's get-filter-element-attributes */
                                                             if (!strcmp(module->ns, LY_NSNC) && !strcmp(s, "get-filter-element-attributes")) {
                                                               LOGDBG("NETCONF filter extension found");
                                                              /* NACM's default-deny-write and default-deny-all */
                                                             } else if (!strcmp(module->ns, LY_NSNACM) &&
                                                                        (!strcmp(s, "default-deny-write") || !strcmp(s, "default-deny-all"))) {
                                                               LOGDBG("NACM extension found");
                                                               /* other extensions are not supported, so inform about such an extension */
                                                             } else {
                                                               LOGWRN("Not supported \"%s\" extension statement found, ignoring.", s);
                                                             }
                                                             free(s);
                                                             s = NULL;
                                                           }
                                                         }
                extension_end

extension_end: ';'
  | '{' stmtsep
        extension_opt_stmt
    '}'

extension_opt_stmt: %empty { $$ = 0; }
  |  extension_opt_stmt argument_stmt { if ($1 & EXTENSION_ARG) {
                                          LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "argument", "extension");
                                          YYABORT;
                                        }
                                        $1 |= EXTENSION_ARG;
                                        $$ = $1;
                                      }
  |  extension_opt_stmt status_stmt { if ($1 & EXTENSION_STA) {
                                        LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "status", "extension");
                                        YYABORT;
                                      }
                                      $1 |= EXTENSION_STA;
                                      $$ = $1;
                                    }
  |  extension_opt_stmt description_stmt { if (read_all) {
                                             free(s);
                                             s= NULL;
                                           }
                                           if ($1 & EXTENSION_DSC) {
                                             LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "description", "extension");
                                             YYABORT;
                                           }
                                           $1 |= EXTENSION_DSC;
                                           $$ = $1;
                                         }
  |  extension_opt_stmt reference_stmt { if (read_all) {
                                           free(s);
                                           s = NULL;
                                         }
                                         if ($1 & EXTENSION_REF) {
                                           LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "reference", "extension");
                                           YYABORT;
                                         }
                                         $1 |= EXTENSION_REF;
                                         $$ = $1;
                                       }

argument_stmt: ARGUMENT_KEYWORD sep identifier_arg_str { free(s); s = NULL; } argument_end stmtsep;

argument_end: ';'
  | '{' stmtsep
        yin_element_stmt
    '}'

yin_element_stmt: YIN_ELEMENT_KEYWORD sep yin_element_arg_str stmtend;

yin_element_arg_str: TRUE_KEYWORD optsep
  | FALSE_KEYWORD optsep
  | string_1 { if (read_all) {
                 if (strcmp(s, "true") && strcmp(s, "false")) {
                    LOGVAL(LYE_INSTMT, LY_VLOG_NONE, NULL, s);
                    free(s);
                    YYABORT;
                 }
                 free(s);
                 s = NULL;
               }
             }

status_stmt:  STATUS_KEYWORD sep status_arg_str stmtend { $$ = $3; }

status_read_stmt:  STATUS_KEYWORD sep { read_all = (read_all) ? LY_READ_ONLY_SIZE : LY_READ_ALL; }
                   status_arg_str { read_all = (read_all) ? LY_READ_ONLY_SIZE : LY_READ_ALL; }
                   stmtend { $$ = $4; }

status_arg_str: CURRENT_KEYWORD optsep { $$ = LYS_STATUS_CURR; }
  | OBSOLETE_KEYWORD optsep { $$ = LYS_STATUS_OBSLT; }
  | DEPRECATED_KEYWORD optsep { $$ = LYS_STATUS_DEPRC; }
  | string_1 { if (read_all) {
                 if (!strcmp(s, "current")) {
                   $$ = LYS_STATUS_CURR;
                 } else if (!strcmp(s, "obsolete")) {
                   $$ = LYS_STATUS_OBSLT;
                 } else if (!strcmp(s, "deprecated")) {
                   $$ = LYS_STATUS_DEPRC;
                 } else {
                   LOGVAL(LYE_INSTMT, LY_VLOG_NONE, NULL, s);
                   free(s);
                   YYABORT;
                 }
                 free(s);
                 s = NULL;
               }
             }

feature_stmt: FEATURE_KEYWORD sep identifier_arg_str { if (read_all) {
                                                         if (!(actual = yang_read_feature(trg, s))) {YYABORT;}
                                                         s=NULL;
                                                       } else {
                                                         size_arrays->features++;
                                                       }
                                                     }
              feature_end

feature_end: ';'
  | '{' stmtsep
        feature_opt_stmt
    '}'
  ;

feature_opt_stmt: %empty { if (read_all) {
                             if (size_arrays->node[size_arrays->next].if_features) {
                               ((struct lys_feature*)actual)->features = calloc(size_arrays->node[size_arrays->next].if_features,
                                                                                sizeof *((struct lys_feature*)actual)->features);
                               if (!((struct lys_feature*)actual)->features) {
                                 LOGMEM;
                                 YYABORT;
                               }
                             }
                             store_flags((struct lys_node *)actual, size_arrays->node[size_arrays->next].flags, 0);
                             size_arrays->next++;
                           } else {
                             $$ = size_arrays->size;
                             if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                               LOGMEM;
                               YYABORT;
                             }
                           }
                         }
  |  feature_opt_stmt if_feature_stmt { if (read_all) {
                                          if (yang_read_if_feature(trg, actual, s, unres, FEATURE_KEYWORD)) {YYABORT;}
                                          s=NULL;
                                        } else {
                                          size_arrays->node[$1].if_features++;
                                        }
                                      }
  |  feature_opt_stmt status_read_stmt { if (!read_all) {
                                           if (yang_check_flags(&size_arrays->node[$1].flags, LYS_STATUS_MASK, "status", "feature", $2, 0)) {
                                             YYABORT;
                                           }
                                         }
                                       }
  |  feature_opt_stmt description_stmt { if (read_all && yang_read_description(trg, actual, s, "feature")) {
                                           YYABORT;
                                         }
                                         s = NULL;
                                       }
  |  feature_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, actual, s, "feature")) {
                                         YYABORT;
                                       }
                                       s = NULL;
                                     }

if_feature_stmt: IF_FEATURE_KEYWORD sep identifier_ref_arg_str stmtend;

identity_stmt: IDENTITY_KEYWORD sep identifier_arg_str { if (read_all) {
                                                           if (!(actual = yang_read_identity(trg,s))) {YYABORT;}
                                                           s = NULL;
                                                         } else {
                                                           size_arrays->ident++;
                                                         }
                                                       }
               identity_end;

identity_end: ';'
  |  '{' stmtsep
         identity_opt_stmt { if (read_all && yang_read_base(module, actual, $3, unres)) {
                               YYABORT;
                             }
                           }
      '}'
  ;

identity_opt_stmt: %empty { $$ = NULL; }
  |  identity_opt_stmt base_stmt { if (read_all) {
                                     if ($1) {
                                       LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "base", "identity");
                                       free(s);
                                       free($1);
                                       YYABORT;
                                     }
                                     $$ = s;
                                     s = NULL;
                                   }
                                 }
  |  identity_opt_stmt status_stmt { if (read_all) {
                                       if (yang_check_flags((uint16_t*)&((struct lys_ident *)actual)->flags, LYS_STATUS_MASK, "status", "identity", $2, 1)) {
                                         YYABORT;
                                       }
                                     }
                                   }
  |  identity_opt_stmt description_stmt { if (read_all && yang_read_description(trg, actual, s, "identity")) {
                                            free($1);
                                            YYABORT;
                                          }
                                          s = NULL;
                                        }
  |  identity_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, actual, s, "identity")) {
                                          free($1);
                                          YYABORT;
                                        }
                                        s = NULL;
                                      }

base_stmt: BASE_KEYWORD sep identifier_ref_arg_str stmtend;

typedef_stmt: TYPEDEF_KEYWORD sep typedef_arg_str
              '{' stmtsep
                  type_opt_stmt { if (read_all) {
                                    if (!($6.node.flag & LYS_TYPE_DEF)) {
                                      LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "type", "typedef");
                                      YYABORT;
                                    }
                                    actual = tpdf_parent;

                                    /* check default value */
                                    if ($6.node.ptr_tpdf->dflt) {
                                      if (unres_schema_add_str(trg, unres, &$6.node.ptr_tpdf->type, UNRES_TYPE_DFLT, $6.node.ptr_tpdf->dflt) == -1) {
                                        YYABORT;
                                      }
                                    }
                                  }
                                }
               '}' ;

typedef_arg_str: identifier_arg_str { if (read_all) {
                                        tpdf_parent = actual;
                                        if (!(actual = yang_read_typedef(trg, actual, s))) {
                                          YYABORT;
                                        }
                                        s = NULL;
                                        actual_type = TYPEDEF_KEYWORD;
                                      }
                                    }

type_stmt: TYPE_KEYWORD sep identifier_ref_arg_str { if (read_all && !(actual = yang_read_type(trg, actual, s, actual_type))) {
                                                       YYABORT;
                                                     }
                                                     s = NULL;
                                                   }
           type_end;

type_opt_stmt: %empty { $$.node.ptr_tpdf = actual;
                        $$.node.flag = 0;
                      }
  |  type_opt_stmt { if (read_all && ($1.node.flag & LYS_TYPE_DEF)) {
                       LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, $1.node.ptr_tpdf, "type", "typedef");
                       YYABORT;
                     }
                   }
     type_stmt stmtsep { if (read_all) {
                   actual = $1.node.ptr_tpdf;
                   actual_type = TYPEDEF_KEYWORD;
                   $1.node.flag |= LYS_TYPE_DEF;
                   $$ = $1;
                   if (unres_schema_add_node(trg, unres, &$1.node.ptr_tpdf->type, UNRES_TYPE_DER, tpdf_parent)) {
                     YYABORT;
                   }
                 }
               }
  |  type_opt_stmt units_stmt { if (read_all && yang_read_units(trg, $1.node.ptr_tpdf, s, TYPEDEF_KEYWORD)) {YYABORT;} s = NULL; }
  |  type_opt_stmt default_stmt { if (read_all && yang_read_default(trg, $1.node.ptr_tpdf, s, TYPEDEF_KEYWORD)) {
                                    YYABORT;
                                  }
                                  s = NULL;
                                  $$ = $1;
                                }
  |  type_opt_stmt status_stmt { if (read_all) {
                                   if (yang_check_flags((uint16_t*)&$1.node.ptr_tpdf->flags, LYS_STATUS_MASK, "status", "typedef", $2, 0)) {
                                     YYABORT;
                                   }
                                 }
                               }
  |  type_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.node.ptr_tpdf, s, "typedef")) {
                                        YYABORT;
                                      }
                                      s = NULL;
                                    }
  |  type_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.node.ptr_tpdf, s, "typedef")) {
                                      YYABORT;
                                    }
                                    s = NULL;
                                  }

type_end: ';'
  |  '{' type_stmtsep
         type_body_stmts
      '}'
  ;

/* store pointer to the structure of yang_type */
type_stmtsep: stmtsep { if (read_all) {
                          $$ = actual;
                        }
                      }

type_body_stmts: decimal_string_restrictions
  | enum_specification
  | path_stmt  { /*leafref_specification */
                 if (read_all) {
                   ((struct yang_type *)actual)->base = LY_TYPE_LEAFREF;
                   ((struct yang_type *)actual)->type->info.lref.path = lydict_insert_zc(trg->ctx, s);
                   s = NULL;
                 }
               }
  | base_stmt  { /*identityref_specification */
                 if (read_all) {
                   ((struct yang_type *)actual)->flags |= LYS_TYPE_BASE;
                   ((struct yang_type *)actual)->base = LY_TYPE_LEAFREF;
                   ((struct yang_type *)actual)->type->info.lref.path = lydict_insert_zc(trg->ctx, s);
                   s = NULL;
                 }
               }
  | require_instance_stmt  { /*instance_identifier_specification */
                             if (read_all) {
                               ((struct yang_type *)actual)->base = LY_TYPE_INST;
                             }
                           }
  | bits_specification
  ;


decimal_string_restrictions: %empty  { if (read_all) {
                                         if (size_arrays->node[size_arrays->next].uni && size_arrays->node[size_arrays->next].pattern) {
                                           LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid restriction in type \"%s\".", ((struct yang_type *)actual)->type->parent->name);
                                           YYABORT;
                                         }
                                         if (size_arrays->node[size_arrays->next].pattern) {
                                           ((struct yang_type *)actual)->type->info.str.patterns = calloc(size_arrays->node[size_arrays->next].pattern, sizeof(struct lys_restr));
                                           if (!((struct yang_type *)actual)->type->info.str.patterns) {
                                             LOGMEM;
                                             YYABORT;
                                           }
                                           ((struct yang_type *)actual)->base = LY_TYPE_STRING;
                                         }
                                         if (size_arrays->node[size_arrays->next].uni) {
                                           ((struct yang_type *)actual)->type->info.uni.types = calloc(size_arrays->node[size_arrays->next].uni, sizeof(struct lys_type));
                                           if (!((struct yang_type *)actual)->type->info.uni.types) {
                                             LOGMEM;
                                             YYABORT;
                                           }
                                           ((struct yang_type *)actual)->base = LY_TYPE_UNION;
                                         }
                                         size_arrays->next++;
                                       } else {
                                         if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                                           LOGMEM;
                                           YYABORT;
                                         }
                                         $$ = size_arrays->size-1;
                                       }
                                     }
  |  decimal_string_restrictions length_stmt
  |  decimal_string_restrictions pattern_stmt { if (!read_all) {
                                                  size_arrays->node[$1].pattern++; /* count of pattern*/
                                                }
                                              }
  |  decimal_string_restrictions fraction_digits_stmt
  |  decimal_string_restrictions range_stmt stmtsep
  |  decimal_string_restrictions union_spec type_stmt stmtsep { if (read_all) {
                                                                  actual = $2;
                                                                } else {
                                                                  size_arrays->node[$1].uni++; /* count of union*/
                                                                }
                                                              }
  ;

  union_spec: %empty { if (read_all) {
                         struct yang_type *typ;
                         struct lys_type *type;

                         typ = (struct yang_type *)actual;
                         $$ = actual;
                         type = &typ->type->info.uni.types[typ->type->info.uni.count++];
                         type->parent = typ->type->parent;
                         actual = type;
                         actual_type = UNION_KEYWORD;
                       }
                     }

fraction_digits_stmt: FRACTION_DIGITS_KEYWORD sep fraction_digits_arg_str
                      stmtend { if (read_all && yang_read_fraction(actual, $3)) {
                                  YYABORT;
                                }
                              }

fraction_digits_arg_str: positive_integer_value optsep { $$ = $1; }
  | string_1 { if (read_all) {
                 char *endptr = NULL;
                 unsigned long val;

                 val = strtoul(s, &endptr, 10);
                 if (*endptr || s[0] == '-' || val == 0 || val > UINT32_MAX) {
                   LOGVAL(LYE_INARG, LY_VLOG_NONE, NULL, s, "fraction-digits");
                   free(s);
                   s = NULL;
                   YYABORT;
                 }
                 $$ = (uint32_t) val;
                 free(s);
                 s =NULL;
               }
             }
  ;

length_stmt: LENGTH_KEYWORD sep length_arg_str length_end stmtsep { actual = $3;
                                                                    actual_type = TYPE_KEYWORD;
                                                                  }

length_arg_str: string { if (read_all) {
                           $$ = actual;
                           if (!(actual = yang_read_length(trg, actual, s))) {
                             YYABORT;
                           }
                           actual_type = LENGTH_KEYWORD;
                           s = NULL;
                         }
                       }

length_end: ';'
  |  '{' stmtsep
         message_opt_stmt
      '}'
  ;

message_opt_stmt: %empty { switch (actual_type) {
                           case MUST_KEYWORD:
                             $$ = "must";
                             break;
                           case LENGTH_KEYWORD:
                             $$ = "length";
                             break;
                           case PATTERN_KEYWORD:
                             $$ = "pattern";
                             break;
                           case RANGE_KEYWORD:
                             $$ = "range";
                             break;
                           }
                         }
  |  message_opt_stmt error_message_stmt { if (read_all && yang_read_message(trg, actual, s, $1, ERROR_MESSAGE_KEYWORD)) {
                                             YYABORT;
                                           }
                                           s = NULL;
                                         }
  |  message_opt_stmt error_app_tag_stmt { if (yang_read_message(trg, actual, s, $1, ERROR_APP_TAG_KEYWORD)) {
                                             YYABORT;
                                           }
                                           s = NULL;
                                         }
  |  message_opt_stmt description_stmt { if (read_all && yang_read_description(trg, actual, s, $1)) {
                                           YYABORT;
                                          }
                                          s = NULL;
                                        }
  |  message_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, actual, s, $1)) {
                                         YYABORT;
                                       }
                                       s = NULL;
                                     }

pattern_stmt: PATTERN_KEYWORD sep pattern_arg_str pattern_end stmtsep { actual = $3;
                                                                        actual_type = TYPE_KEYWORD;
                                                                      }

pattern_arg_str: string { if (read_all) {
                            $$ = actual;
                            if (!(actual = yang_read_pattern(trg, actual, s))) {
                              YYABORT;
                            }
                            actual_type = PATTERN_KEYWORD;
                            s = NULL;
                          }
                        }

pattern_end: ';'
  |  '{' stmtsep
         message_opt_stmt
     '}'
  ;

enum_specification: { if (read_all) {
                        if (size_arrays->node[size_arrays->next].enm) {
                          ((struct yang_type *)actual)->type->info.enums.enm = calloc(size_arrays->node[size_arrays->next++].enm, sizeof(struct lys_type_enum));
                          if (!((struct yang_type *)actual)->type->info.enums.enm) {
                            LOGMEM;
                            YYABORT;
                          }
                        }
                        ((struct yang_type *)actual)->base = LY_TYPE_ENUM;
                        cnt_val = 0;
                      } else {
                        if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                          LOGMEM;
                          YYABORT;
                        }
                      }
                    } enum_stmt stmtsep enum_stmts;

enum_stmts: %empty
  | enum_stmts enum_stmt stmtsep;


enum_stmt: ENUM_KEYWORD sep enum_arg_str enum_end
           { if (read_all) {
               if (yang_check_enum($3, actual, &cnt_val, actual_type)) {
                 YYABORT;
               }
               actual = $3;
               actual_type = TYPE_KEYWORD;
             } else {
               size_arrays->node[size_arrays->size-1].enm++; /* count of enum*/
             }
           }

enum_arg_str: string { if (read_all) {
                         $$ = actual;
                         if (!(actual = yang_read_enum(trg, actual, s))) {
                           YYABORT;
                         }
                         s = NULL;
                         actual_type = 0;
                       }
                     }

enum_end: ';'
  |  '{' stmtsep
         enum_opt_stmt
     '}'
  ;

enum_opt_stmt: %empty
  |  enum_opt_stmt value_stmt { /* actual_type - it is used to check value of enum statement*/
                                if (read_all) {
                                  if (actual_type) {
                                    LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "value", "enum");
                                    YYABORT;
                                  }
                                  actual_type = 1;
                                }
                              }
  |  enum_opt_stmt status_stmt { if (read_all) {
                                   if (yang_check_flags((uint16_t*)&((struct lys_type_enum *)actual)->flags, LYS_STATUS_MASK, "status", "enum", $2, 1)) {
                                     YYABORT;
                                   }
                                 }
                               }
  |  enum_opt_stmt description_stmt { if (read_all && yang_read_description(trg, actual, s, "enum")) {
                                        YYABORT;
                                      }
                                      s = NULL;
                                    }
  |  enum_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, actual, s, "enum")) {
                                      YYABORT;
                                    }
                                    s = NULL;
                                  }

value_stmt: VALUE_KEYWORD sep integer_value_arg_str
            stmtend { if (read_all) {
                        ((struct lys_type_enum *)actual)->value = $3;

                        /* keep the highest enum value for automatic increment */
                        if ($3 > cnt_val) {
                          cnt_val = $3;
                        }
                        cnt_val++;
                      }
                    }

integer_value_arg_str: integer_value optsep { $$ = $1; }
  |  string_1 { if (read_all) {
                  /* convert it to int32_t */
                  int64_t val;
                  char *endptr;

                  val = strtoll(s, &endptr, 10);
                  if (val < INT32_MIN || val > INT32_MAX || *endptr) {
                      LOGVAL(LYE_INARG, LY_VLOG_NONE, NULL, s, "value");
                      free(s);
                      YYABORT;
                  }
                  free(s);
                  s = NULL;
                  $$ = (int32_t) val;
               }
             }
  ;

range_stmt: RANGE_KEYWORD sep range_arg_str range_end { actual = $3;
                                                        actual_type = RANGE_KEYWORD;
                                                      }


range_end: ';'
  |  '{' stmtsep
         message_opt_stmt
      '}'
   ;

path_stmt: PATH_KEYWORD sep path_arg_str stmtend;

require_instance_stmt: REQUIRE_INSTANCE_KEYWORD sep require_instance_arg_str stmtend;

require_instance_arg_str: TRUE_KEYWORD optsep { if (read_all) {
                                                  ((struct yang_type *)actual)->type->info.inst.req = 1;
                                                }
                                              }
  |  FALSE_KEYWORD optsep { if (read_all) {
                              ((struct yang_type *)actual)->type->info.inst.req = -1;
                            }
                          }
  |  string_1 { if (read_all) {
                  if (!strcmp(s,"true")) {
                    ((struct yang_type *)actual)->type->info.inst.req = 1;
                  } else if (!strcmp(s,"false")) {
                    ((struct yang_type *)actual)->type->info.inst.req = -1;
                  } else {
                    LOGVAL(LYE_INARG, LY_VLOG_NONE, NULL, s, "require-instance");
                    free(s);
                    YYABORT;
                  }
                  free(s);
                }
              }
  ;

bits_specification: { if (read_all) {
                        if (size_arrays->node[size_arrays->next].bit) {
                          ((struct yang_type *)actual)->type->info.bits.bit = calloc(size_arrays->node[size_arrays->next++].bit, sizeof(struct lys_type_bit));
                          if (!((struct yang_type *)actual)->type->info.bits.bit) {
                            LOGMEM;
                            YYABORT;
                          }
                        }
                        ((struct yang_type *)actual)->base = LY_TYPE_BITS;
                        cnt_val = 0;
                      } else {
                        if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                          LOGMEM;
                          YYABORT;
                        }
                      }
                    } bit_stmt bit_stmts

bit_stmts: %empty
  | bit_stmts bit_stmt;

bit_stmt: BIT_KEYWORD sep bit_arg_str bit_end
          stmtsep { if (read_all) {
                      if (yang_check_bit($3, actual, &cnt_val, actual_type)) {
                        YYABORT;
                      }
                      actual = $3;
                    } else {
                      size_arrays->node[size_arrays->size-1].bit++; /* count of bit*/
                    }
                  }

bit_arg_str: identifier_arg_str { if (read_all) {
                                    $$ = actual;
                                    if (!(actual = yang_read_bit(trg, actual, s))) {
                                      YYABORT;
                                    }
                                    s = NULL;
                                    actual_type = 0;
                                  }
                                }

bit_end: ';'
  |  '{' stmtsep
         bit_opt_stmt
     '}'
  ;

bit_opt_stmt: %empty
  |  bit_opt_stmt position_stmt { /* actual_type - it is used to check position of bit statement*/
                                  if (read_all) {
                                    if (actual_type) {
                                      LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "position", "bit");
                                      YYABORT;
                                    }
                                    actual_type = 1;
                                  }
                                }
  |  bit_opt_stmt status_stmt { if (read_all) {
                                  if (yang_check_flags((uint16_t*)&((struct lys_type_bit *)actual)->flags, LYS_STATUS_MASK, "status", "bit", $2, 1)) {
                                    YYABORT;
                                  }
                                }
                              }
  |  bit_opt_stmt description_stmt { if (read_all && yang_read_description(trg, actual, s, "bit")) {
                                       YYABORT;
                                     }
                                     s = NULL;
                                   }
  |  bit_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, actual, s, "bit")) {
                                     YYABORT;
                                   }
                                   s = NULL;
                                 }

position_stmt: POSITION_KEYWORD sep position_value_arg_str
               stmtend { if (read_all) {
                           ((struct lys_type_bit *)actual)->pos = $3;

                           /* keep the highest position value for automatic increment */
                           if ($3 > cnt_val) {
                             cnt_val = $3;
                           }
                           cnt_val++;
                         }
                       }

position_value_arg_str: non_negative_integer_value optsep { $$ = $1; }
  |  string_1 { /* convert it to uint32_t */
                unsigned long val;
                char *endptr;

                val = strtoul(s, &endptr, 10);
                if (val > UINT32_MAX || s[0] == '-' || *endptr) {
                    LOGVAL(LYE_INARG, LY_VLOG_NONE, NULL, s, "position");
                    free(s);
                    YYABORT;
                }
                free(s);
                s = NULL;
                $$ = (uint32_t) val;
              }

error_message_stmt: ERROR_MESSAGE_KEYWORD sep string stmtend;

error_app_tag_stmt: ERROR_APP_TAG_KEYWORD sep string stmtend;

units_stmt: UNITS_KEYWORD sep string stmtend;

default_stmt: DEFAULT_KEYWORD sep string stmtend;

grouping_stmt: GROUPING_KEYWORD sep identifier_arg_str { if (read_all) {
                                                           if (!(actual = yang_read_node(trg,actual,s,LYS_GROUPING,sizeof(struct lys_node_grp)))) {YYABORT;}
                                                           s=NULL;
                                                         }
                                                       }
               grouping_end;

grouping_end: ';'
  |  '{' stmtsep
         grouping_opt_stmt
     '}'
  ;

grouping_opt_stmt: %empty { if (read_all) {
                               $$.grouping = actual;
                               actual_type = GROUPING_KEYWORD;
                               if (size_arrays->node[size_arrays->next].tpdf) {
                                 $$.grouping->tpdf = calloc(size_arrays->node[size_arrays->next].tpdf, sizeof *$$.grouping->tpdf);
                                 if (!$$.grouping->tpdf) {
                                   LOGMEM;
                                   YYABORT;
                                 }
                               }
                               store_flags((struct lys_node *)$$.grouping, size_arrays->node[size_arrays->next].flags, 0);
                               size_arrays->next++;
                             } else {
                               $$.index = size_arrays->size;
                               if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                                 LOGMEM;
                                 YYABORT;
                               }
                             }
                           }
  |  grouping_opt_stmt status_read_stmt { if (!read_all) {
                                            if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "grouping", $2, 0)) {
                                              YYABORT;
                                            }
                                          }
                                        }
  |  grouping_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.grouping, s, "grouping")) {
                                            YYABORT;
                                          }
                                          s = NULL;
                                        }
  |  grouping_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.grouping, s, "grouping")) {
                                          YYABORT;
                                        }
                                        s = NULL;
                                      }
  |  grouping_opt_stmt grouping_stmt stmtsep { actual = $1.grouping; actual_type = GROUPING_KEYWORD; }
  |  grouping_opt_stmt typedef_stmt stmtsep { if (read_all) {
                                                actual = $1.grouping;
                                                actual_type = GROUPING_KEYWORD;
                                              } else {
                                                size_arrays->node[$1.index].tpdf++;
                                              }
                                            }
  |  grouping_opt_stmt data_def_stmt stmtsep { actual = $1.grouping; actual_type = GROUPING_KEYWORD; }
  ;

data_def_stmt: container_stmt
  |  leaf_stmt
  |  leaf_list_stmt
  |  list_stmt
  |  choice_stmt
  |  anyxml_stmt
  |  uses_stmt
  ;

container_stmt: CONTAINER_KEYWORD sep identifier_arg_str { if (read_all) {
                                                             if (!(actual = yang_read_node(trg,actual,s,LYS_CONTAINER,sizeof(struct lys_node_container)))) {YYABORT;}
                                                             data_node = actual;
                                                             s=NULL;
                                                           }
                                                         }
                container_end ;

container_end: ';'
  |  '{' stmtsep
         container_opt_stmt
      '}'
  ;

container_opt_stmt: %empty { if (read_all) {
                               $$.container = actual;
                               actual_type = CONTAINER_KEYWORD;
                               if (size_arrays->node[size_arrays->next].if_features) {
                                 $$.container->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.container->features);
                                 if (!$$.container->features) {
                                   LOGMEM;
                                   YYABORT;
                                 }
                               }
                               if (size_arrays->node[size_arrays->next].must) {
                                 $$.container->must = calloc(size_arrays->node[size_arrays->next].must, sizeof *$$.container->must);
                                 if (!$$.container->must) {
                                   LOGMEM;
                                   YYABORT;
                                 }
                               }
                               if (size_arrays->node[size_arrays->next].tpdf) {
                                 $$.container->tpdf = calloc(size_arrays->node[size_arrays->next].tpdf, sizeof *$$.container->tpdf);
                                 if (!$$.container->tpdf) {
                                   LOGMEM;
                                   YYABORT;
                                 }
                               }
                               store_flags((struct lys_node *)$$.container, size_arrays->node[size_arrays->next].flags, config_inherit);
                               size_arrays->next++;
                             } else {
                               $$.index = size_arrays->size;
                               if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                                 LOGMEM;
                                 YYABORT;
                               }
                             }
                           }
  |  container_opt_stmt when_stmt { actual = $1.container; actual_type = CONTAINER_KEYWORD; }
     stmtsep
  |  container_opt_stmt if_feature_stmt { if (read_all) {
                                            if (yang_read_if_feature(trg, $1.container, s, unres, CONTAINER_KEYWORD)) {YYABORT;}
                                            s=NULL;
                                          } else {
                                            size_arrays->node[$1.index].if_features++;
                                          }
                                        }
  |  container_opt_stmt must_stmt { if (read_all) {
                                      actual = $1.container;
                                      actual_type = CONTAINER_KEYWORD;
                                    } else {
                                      size_arrays->node[$1.index].must++;
                                    }
                                  }
     stmtsep
  |  container_opt_stmt presence_stmt { if (read_all && yang_read_presence(trg, $1.container, s)) {YYABORT;} s=NULL; }
  |  container_opt_stmt config_read_stmt { if (!read_all) {
                                             if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_CONFIG_MASK, "config", "container", $2, 0)) {
                                               YYABORT;
                                             }
                                           }
                                         }
  |  container_opt_stmt status_read_stmt { if (!read_all) {
                                             if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "container", $2, 0)) {
                                               YYABORT;
                                             }
                                           }
                                         }
  |  container_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.container, s, "container")) {
                                             YYABORT;
                                           }
                                           s = NULL;
                                         }
  |  container_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.container, s, "container")) {
                                           YYABORT;
                                         }
                                         s = NULL;
                                       }
  |  container_opt_stmt grouping_stmt { actual = $1.container;
                                        actual_type = CONTAINER_KEYWORD;
                                        data_node = actual;
                                      }
     stmtsep
  |  container_opt_stmt typedef_stmt { if (read_all) {
                                                 actual = $1.container;
                                                 actual_type = CONTAINER_KEYWORD;
                                               } else {
                                                 size_arrays->node[$1.index].tpdf++;
                                               }
                                             }
     stmtsep
  |  container_opt_stmt data_def_stmt { actual = $1.container;
                                        actual_type = CONTAINER_KEYWORD;
                                        data_node = actual;
                                      }
     stmtsep
  ;

leaf_stmt: LEAF_KEYWORD sep identifier_arg_str { if (read_all) {
                                                   if (!(actual = yang_read_node(trg,actual,s,LYS_LEAF,sizeof(struct lys_node_leaf)))) {YYABORT;}
                                                   data_node = actual;
                                                   s=NULL;
                                                 }
                                               }
           '{' stmtsep
               leaf_opt_stmt  { if (read_all) {
                                  if (!($7.node.flag & LYS_TYPE_DEF)) {
                                    LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_LYS, $7.node.ptr_leaf, "type", "leaf");
                                    YYABORT;
                                  }
                                  if ($7.node.ptr_leaf->dflt) {
                                    if ($7.node.ptr_leaf->flags & LYS_MAND_TRUE) {
                                      /* RFC 6020, 7.6.4 - default statement must not with mandatory true */
                                      LOGVAL(LYE_INCHILDSTMT, LY_VLOG_LYS, $7.node.ptr_leaf, "mandatory", "leaf");
                                      LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "The \"mandatory\" statement is forbidden on leaf with \"default\".");
                                      YYABORT;
                                    }
                                    if (unres_schema_add_str(trg, unres, &$7.node.ptr_leaf->type, UNRES_TYPE_DFLT, $7.node.ptr_leaf->dflt) == -1) {
                                      YYABORT;
                                    }
                                  }
                                }
                              }
             '}' ;

  leaf_opt_stmt: %empty { if (read_all) {
                            $$.node.ptr_leaf = actual;
                            $$.node.flag = 0;
                            actual_type = LEAF_KEYWORD;
                            if (size_arrays->node[size_arrays->next].if_features) {
                              $$.node.ptr_leaf->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.node.ptr_leaf->features);
                              if (!$$.node.ptr_leaf->features) {
                                LOGMEM;
                                YYABORT;
                              }
                            }
                            if (size_arrays->node[size_arrays->next].must) {
                              $$.node.ptr_leaf->must = calloc(size_arrays->node[size_arrays->next].must, sizeof *$$.node.ptr_leaf->must);
                              if (!$$.node.ptr_leaf->must) {
                                LOGMEM;
                                YYABORT;
                              }
                            }
                            store_flags((struct lys_node *)$$.node.ptr_leaf, size_arrays->node[size_arrays->next].flags, config_inherit);
                            size_arrays->next++;
                          } else {
                            $$.index = size_arrays->size;
                            if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                        }
    |  leaf_opt_stmt when_stmt { actual = $1.node.ptr_leaf; actual_type = LEAF_KEYWORD; }
       stmtsep
    |  leaf_opt_stmt if_feature_stmt { if (read_all) {
                                         if (yang_read_if_feature(trg, $1.node.ptr_leaf, s, unres, LEAF_KEYWORD)) {YYABORT;}
                                         s=NULL;
                                       } else {
                                         size_arrays->node[$1.index].if_features++;
                                       }
                                     }
    |  leaf_opt_stmt { if (read_all && ($1.node.flag & LYS_TYPE_DEF)) {
                         LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_leaf, "type", "leaf");
                         YYABORT;
                       }
                     }
       type_stmt { if (read_all) {
                     actual = $1.node.ptr_leaf;
                     actual_type = LEAF_KEYWORD;
                     $1.node.flag |= LYS_TYPE_DEF;
                     if (unres_schema_add_node(trg, unres, &$1.node.ptr_leaf->type, UNRES_TYPE_DER,(struct lys_node *)$1.node.ptr_leaf->parent)) {
                       YYABORT;
                     }
                   }
                 }
       stmtsep { $$ = $1;}
    |  leaf_opt_stmt units_stmt { if (read_all && yang_read_units(trg, $1.node.ptr_leaf, s, LEAF_KEYWORD)) {YYABORT;} s = NULL; }
    |  leaf_opt_stmt must_stmt { if (read_all) {
                                   actual = $1.node.ptr_leaf;
                                   actual_type = LEAF_KEYWORD;
                                 } else {
                                   size_arrays->node[$1.index].must++;
                                 }
                               }
       stmtsep
    |  leaf_opt_stmt default_stmt { if (read_all && yang_read_default(trg, $1.node.ptr_leaf, s, LEAF_KEYWORD)) {YYABORT;}
                                    s = NULL;
                                  }
    |  leaf_opt_stmt config_read_stmt { if (!read_all) {
                                               if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_CONFIG_MASK, "config", "leaf", $2, 0)) {
                                                 YYABORT;
                                               }
                                             }
                                           }
    |  leaf_opt_stmt mandatory_read_stmt { if (!read_all) {
                                             if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_MAND_MASK, "mandatory", "leaf", $2, 0)) {
                                               YYABORT;
                                             }
                                           }
                                         }
    |  leaf_opt_stmt status_read_stmt { if (!read_all) {
                                          if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "leaf", $2, 0)) {
                                            YYABORT;
                                          }
                                        }
                                      }
    |  leaf_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.node.ptr_leaf, s, "leaf")) {
                                          YYABORT;
                                        }
                                        s = NULL;
                                      }
    |  leaf_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.node.ptr_leaf, s, "leaf")) {
                                        YYABORT;
                                      }
                                      s = NULL;
                                    }

  leaf_list_stmt: LEAF_LIST_KEYWORD sep identifier_arg_str { if (read_all) {
                                                               if (!(actual = yang_read_node(trg,actual,s,LYS_LEAFLIST,sizeof(struct lys_node_leaflist)))) {YYABORT;}
                                                               data_node = actual;
                                                               s=NULL;
                                                             }
                                                           }
                  '{' stmtsep
                      leaf_list_opt_stmt { if (read_all) {
                                             if ($7.node.ptr_leaflist->flags & LYS_CONFIG_R) {
                                               /* RFC 6020, 7.7.5 - ignore ordering when the list represents state data
                                                * ignore oredering MASK - 0x7F
                                                */
                                             $7.node.ptr_leaflist->flags &= 0x7F;
                                           }
                                           if ($7.node.ptr_leaflist->max && $7.node.ptr_leaflist->min > $7.node.ptr_leaflist->max) {
                                             LOGVAL(LYE_SPEC, LY_VLOG_LYS, $7.node.ptr_leaflist, "\"min-elements\" is bigger than \"max-elements\".");
                                             YYABORT;
                                           }
                                           if (!($7.node.flag & LYS_TYPE_DEF)) {
                                             LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_LYS, $7.node.ptr_leaflist, "type", "leaf-list");
                                             YYABORT;
                                           }
                                         }
                                       }
                '}' ;

leaf_list_opt_stmt: %empty { if (read_all) {
                               $$.node.ptr_leaflist = actual;
                               $$.node.flag = 0;
                               actual_type = LEAF_LIST_KEYWORD;
                               if (size_arrays->node[size_arrays->next].if_features) {
                                 $$.node.ptr_leaflist->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.node.ptr_leaflist->features);
                                 if (!$$.node.ptr_leaflist->features) {
                                   LOGMEM;
                                   YYABORT;
                                 }
                               }
                               if (size_arrays->node[size_arrays->next].must) {
                                 $$.node.ptr_leaflist->must = calloc(size_arrays->node[size_arrays->next].must, sizeof *$$.node.ptr_leaflist->must);
                                 if (!$$.node.ptr_leaflist->must) {
                                   LOGMEM;
                                   YYABORT;
                                 }
                               }
                               store_flags((struct lys_node *)$$.node.ptr_leaflist, size_arrays->node[size_arrays->next].flags, config_inherit);
                               size_arrays->next++;
                             } else {
                               $$.index = size_arrays->size;
                               if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                                 LOGMEM;
                                 YYABORT;
                               }
                             }
                           }
  |  leaf_list_opt_stmt when_stmt { actual = $1.node.ptr_leaflist; actual_type = LEAF_LIST_KEYWORD; }
     stmtsep
  |  leaf_list_opt_stmt if_feature_stmt { if (read_all) {
                                            if (yang_read_if_feature(trg, $1.node.ptr_leaflist, s, unres, LEAF_LIST_KEYWORD)) {YYABORT;}
                                            s=NULL;
                                          } else {
                                            size_arrays->node[$1.index].if_features++;
                                          }
                                        }
  |  leaf_list_opt_stmt { if (read_all && ($1.node.flag & LYS_TYPE_DEF)) {
                            LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_leaflist, "type", "leaf-list");
                            YYABORT;
                          }
                        }
     type_stmt { if (read_all) {
                   actual = $1.node.ptr_leaflist;
                   actual_type = LEAF_LIST_KEYWORD;
                   $1.node.flag |= LYS_TYPE_DEF;
                   if (unres_schema_add_node(trg, unres, &$1.node.ptr_leaflist->type, UNRES_TYPE_DER, (struct lys_node *)$1.node.ptr_leaflist->parent)) {
                     YYABORT;
                   }
                 }
               }
     stmtsep { $$ = $1; }
  |  leaf_list_opt_stmt units_stmt { if (read_all && yang_read_units(trg, $1.node.ptr_leaflist, s, LEAF_LIST_KEYWORD)) {YYABORT;} s = NULL; }
  |  leaf_list_opt_stmt must_stmt { if (read_all) {
                                      actual = $1.node.ptr_leaflist;
                                      actual_type = LEAF_LIST_KEYWORD;
                                    } else {
                                      size_arrays->node[$1.index].must++;
                                    }
                                  }
     stmtsep
  |  leaf_list_opt_stmt config_read_stmt { if (!read_all) {
                                             if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_CONFIG_MASK, "config", "leaf-list", $2, 0)) {
                                               YYABORT;
                                             }
                                           }
                                         }
  |  leaf_list_opt_stmt min_elements_stmt { if (read_all) {
                                              if ($1.node.flag & LYS_MIN_ELEMENTS) {
                                                LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_leaflist, "min-elements", "leaf-list");
                                                YYABORT;
                                              }
                                              $1.node.ptr_leaflist->min = $2;
                                              $1.node.flag |= LYS_MIN_ELEMENTS;
                                              $$ = $1;
                                              if ($1.node.ptr_leaflist->max && ($1.node.ptr_leaflist->min > $1.node.ptr_leaflist->max)) {
                                                LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid value \"%d\" of \"%s\".", $2, "min-elements");
                                                LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "\"min-elements\" is bigger than \"max-elements\".");
                                              }
                                            }
                                          }
  |  leaf_list_opt_stmt max_elements_stmt { if (read_all) {
                                              if ($1.node.flag & LYS_MAX_ELEMENTS) {
                                                LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_leaflist, "max-elements", "leaf-list");
                                                YYABORT;
                                              }
                                              $1.node.ptr_leaflist->max = $2;
                                              $1.node.flag |= LYS_MAX_ELEMENTS;
                                              $$ = $1;
                                              if ($1.node.ptr_leaflist->min > $1.node.ptr_leaflist->max) {
                                                LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid value \"%d\" of \"%s\".", $2, "max-elements");
                                                LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "\"max-elements\" is smaller than \"min-elements\".");
                                              }
                                            }
                                          }
  |  leaf_list_opt_stmt ordered_by_stmt { if (read_all) {
                                            if ($1.node.flag & LYS_ORDERED_MASK) {
                                              LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_leaflist, "ordered by", "leaf-list");
                                              YYABORT;
                                            }
                                            if ($2 & LYS_USERORDERED) {
                                              $1.node.ptr_leaflist->flags |= LYS_USERORDERED;
                                            }
                                            $1.node.flag |= $2;
                                            $$ = $1;
                                          }
                                        }
  |  leaf_list_opt_stmt status_read_stmt { if (!read_all) {
                                             if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "leaf-list", $2, 0)) {
                                               YYABORT;
                                             }
                                           }
                                         }
  |  leaf_list_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.node.ptr_leaflist, s, "leaf-list")) {
                                             YYABORT;
                                           }
                                           s = NULL;
                                         }
  |  leaf_list_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.node.ptr_leaflist, s, "leaf-list")) {
                                           YYABORT;
                                         }
                                         s = NULL;
                                       }

list_stmt: LIST_KEYWORD sep identifier_arg_str { if (read_all) {
                                                   if (!(actual = yang_read_node(trg,actual,s,LYS_LIST,sizeof(struct lys_node_list)))) {YYABORT;}
                                                   data_node = actual;
                                                   s=NULL;
                                                 }
                                               }
           '{' stmtsep
               list_opt_stmt { if (read_all) {
                                 if ($7.node.ptr_list->flags & LYS_CONFIG_R) {
                                   /* RFC 6020, 7.7.5 - ignore ordering when the list represents state data
                                    * ignore oredering MASK - 0x7F
                                    */
                                   $7.node.ptr_list->flags &= 0x7F;
                                 }
                                 if (($7.node.ptr_list->flags & LYS_CONFIG_W) && !$7.node.ptr_list->keys) {
                                   LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_LYS, $7.node.ptr_list, "key", "list");
                                   YYABORT;
                                 }
                                 if ($7.node.ptr_list->keys && yang_read_key(trg, $7.node.ptr_list, unres)) {
                                   YYABORT;
                                 }
                                 if (!($7.node.flag & LYS_DATADEF)) {
                                   LOGVAL(LYE_SPEC, LY_VLOG_LYS, $7.node.ptr_list, "data-def statement missing.");
                                   YYABORT;
                                 }
                                 if (yang_read_unique(trg, $7.node.ptr_list, unres)) {
                                   YYABORT;
                                 }
                               }
                             }
            '}' ;

list_opt_stmt: %empty { if (read_all) {
                          $$.node.ptr_list = actual;
                          $$.node.flag = 0;
                          if (size_arrays->node[size_arrays->next].if_features) {
                            $$.node.ptr_list->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.node.ptr_list->features);
                            if (!$$.node.ptr_list->features) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                          if (size_arrays->node[size_arrays->next].must) {
                            $$.node.ptr_list->must = calloc(size_arrays->node[size_arrays->next].must, sizeof *$$.node.ptr_list->must);
                            if (!$$.node.ptr_list->must) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                          if (size_arrays->node[size_arrays->next].tpdf) {
                            $$.node.ptr_list->tpdf = calloc(size_arrays->node[size_arrays->next].tpdf, sizeof *$$.node.ptr_list->tpdf);
                            if (!$$.node.ptr_list->tpdf) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                          if (size_arrays->node[size_arrays->next].unique) {
                            $$.node.ptr_list->unique = calloc(size_arrays->node[size_arrays->next].unique, sizeof *$$.node.ptr_list->unique);
                            if (!$$.node.ptr_list->unique) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                          store_flags((struct lys_node *)$$.node.ptr_list, size_arrays->node[size_arrays->next].flags, config_inherit);
                          size_arrays->next++;
                        } else {
                          $$.index = size_arrays->size;
                          if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                            LOGMEM;
                            YYABORT;
                          }
                        }
                      }
  |  list_opt_stmt when_stmt { actual = $1.node.ptr_list; actual_type = LIST_KEYWORD; }
     stmtsep
  |  list_opt_stmt if_feature_stmt { if (read_all) {
                                       if (yang_read_if_feature(trg, $1.node.ptr_list, s, unres, LIST_KEYWORD)) {YYABORT;}
                                       s=NULL;
                                     } else {
                                       size_arrays->node[$1.index].if_features++;
                                     }
                                   }
  |  list_opt_stmt must_stmt { if (read_all) {
                                 actual = $1.node.ptr_list;
                                 actual_type = LIST_KEYWORD;
                               } else {
                                 size_arrays->node[$1.index].must++;
                               }
                             }
     stmtsep
  |  list_opt_stmt key_stmt { if (read_all) {
                                if ($1.node.ptr_list->keys) {
                                  LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_list, "key", "list");
                                  YYABORT;
                                }
                                $1.node.ptr_list->keys = (struct lys_node_leaf **)s;
                                $$ = $1;
                                s=NULL;
                              }
                            }
  |  list_opt_stmt unique_stmt { if (read_all) {
                                   $1.node.ptr_list->unique[$1.node.ptr_list->unique_size++].expr = (const char **)s;
                                   $$ = $1;
                                   s = NULL;
                                 } else {
                                   size_arrays->node[$1.index].unique++;
                                 }
                               }
  |  list_opt_stmt config_read_stmt { if (!read_all) {
                                        if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_CONFIG_MASK, "config", "list", $2, 0)) {
                                          YYABORT;
                                        }
                                      }
                                    }
  |  list_opt_stmt min_elements_stmt { if (read_all) {
                                         if ($1.node.flag & LYS_MIN_ELEMENTS) {
                                           LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_list, "min-elements", "list");
                                           YYABORT;
                                         }
                                         $1.node.ptr_list->min = $2;
                                         $1.node.flag |= LYS_MIN_ELEMENTS;
                                         $$ = $1;
                                         if ($1.node.ptr_list->max && ($1.node.ptr_list->min > $1.node.ptr_list->max)) {
                                           LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid value \"%d\" of \"%s\".", $2, "min-elements");
                                           LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "\"min-elements\" is bigger than \"max-elements\".");
                                         }
                                       }
                                     }
  |  list_opt_stmt max_elements_stmt { if (read_all) {
                                         if ($1.node.flag & LYS_MAX_ELEMENTS) {
                                           LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_list, "max-elements", "list");
                                           YYABORT;
                                         }
                                         $1.node.ptr_list->max = $2;
                                         $1.node.flag |= LYS_MAX_ELEMENTS;
                                         $$ = $1;
                                         if ($1.node.ptr_list->min > $1.node.ptr_list->max) {
                                           LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid value \"%d\" of \"%s\".", $2, "min-elements");
                                           LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "\"max-elements\" is smaller than \"min-elements\".");
                                         }
                                       }
                                     }
  |  list_opt_stmt ordered_by_stmt { if (read_all) {
                                       if ($1.node.flag & LYS_ORDERED_MASK) {
                                         LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_list, "ordered by", "list");
                                         YYABORT;
                                       }
                                       if ($2 & LYS_USERORDERED) {
                                         $1.node.ptr_list->flags |= LYS_USERORDERED;
                                       }
                                       $1.node.flag |= $2;
                                       $$ = $1;
                                     }
                                   }
  |  list_opt_stmt status_read_stmt { if (!read_all) {
                                        if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "list", $2, 0)) {
                                          YYABORT;
                                        }
                                      }
                                    }
  |  list_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.node.ptr_list, s, "list")) {
                                        YYABORT;
                                      }
                                      s = NULL;
                                    }
  |  list_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.node.ptr_list, s, "list")) {
                                      YYABORT;
                                    }
                                    s = NULL;
                                  }
  |  list_opt_stmt typedef_stmt { if (read_all) {
                                            actual = $1.node.ptr_list;
                                            actual_type = LIST_KEYWORD;
                                          } else {
                                            size_arrays->node[$1.index].tpdf++;
                                          }
                                        }
     stmtsep
  |  list_opt_stmt grouping_stmt { actual = $1.node.ptr_list;
                                   actual_type = LIST_KEYWORD;
                                   data_node = actual;
                                 }
     stmtsep
  |  list_opt_stmt data_def_stmt { actual = $1.node.ptr_list;
                                   actual_type = LIST_KEYWORD;
                                   $1.node.flag |= LYS_DATADEF;
                                   data_node = actual;
                                 }
     stmtsep { $$ = $1; }
  ;

choice_stmt: CHOICE_KEYWORD sep identifier_arg_str { if (read_all) {
                                                       if (!(actual = yang_read_node(trg,actual,s,LYS_CHOICE,sizeof(struct lys_node_choice)))) {YYABORT;}
                                                       data_node = actual;
                                                       if (data_node->parent && (data_node->parent->nodetype == LYS_GROUPING)) {
                                                         data_node = NULL;
                                                       }
                                                       s=NULL;
                                                     }
                                                   }
             choice_end;

choice_end: ';'
  |  '{' stmtsep
         choice_opt_stmt  { if (read_all) {
                              if ($3.choice.s && ($3.choice.ptr_choice->flags & LYS_MAND_TRUE)) {
                                LOGVAL(LYE_INCHILDSTMT, LY_VLOG_NONE, NULL, "default", "choice");
                                LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "The \"default\" statement is forbidden on choices with \"mandatory\".");
                                YYABORT;
                              }
                              /* link default with the case */
                              if ($3.choice.s) {
                                if (unres_schema_add_str(trg, unres, $3.choice.ptr_choice, UNRES_CHOICE_DFLT, $3.choice.s) == -1) {
                                  YYABORT;
                                }
                                free($3.choice.s);
                              }
                            }
                          }
     '}' ;

choice_opt_stmt: %empty { if (read_all) {
                            $$.choice.ptr_choice = actual;
                            $$.choice.s = NULL;
                            actual_type = CHOICE_KEYWORD;
                            if (size_arrays->node[size_arrays->next].if_features) {
                              $$.choice.ptr_choice->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.choice.ptr_choice->features);
                              if (!$$.choice.ptr_choice->features) {
                                LOGMEM;
                                YYABORT;
                              }
                            }
                            store_flags((struct lys_node *)$$.choice.ptr_choice, size_arrays->node[size_arrays->next].flags, config_inherit);
                            size_arrays->next++;
                          } else {
                            $$.index = size_arrays->size;
                            if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                        }
  |  choice_opt_stmt when_stmt { actual = $1.choice.ptr_choice; actual_type = CHOICE_KEYWORD; }
     stmtsep { $$ = $1; }
  |  choice_opt_stmt if_feature_stmt { if (read_all) {
                                         if (yang_read_if_feature(trg, $1.choice.ptr_choice,s, unres, CHOICE_KEYWORD)) {
                                           if ($1.choice.s) {
                                             free($1.choice.s);
                                           }
                                           YYABORT;
                                         }
                                         s=NULL;
                                         $$ = $1;
                                       } else {
                                         size_arrays->node[$1.index].if_features++;
                                       }
                                     }
  |  choice_opt_stmt default_stmt { if (read_all) {
                                      if ($1.choice.s) {
                                        LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.choice.ptr_choice, "default", "choice");
                                        free($1.choice.s);
                                        free(s);
                                        YYABORT;
                                      }
                                      $1.choice.s = s;
                                      s = NULL;
                                      $$ = $1;
                                    }
                                  }
  |  choice_opt_stmt config_read_stmt { if (!read_all) {
                                           if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_CONFIG_MASK, "config", "choice", $2, 0)) {
                                             YYABORT;
                                           }
                                         } else {
                                          $$ = $1;
                                         }
                                       }
|  choice_opt_stmt mandatory_read_stmt { if (!read_all) {
                                      if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_MAND_MASK, "mandatory", "choice", $2, 0)) {
                                        YYABORT;
                                      }
                                    } else {
                                      $$ = $1;
                                    }
                                  }
  |  choice_opt_stmt status_read_stmt { if (!read_all) {
                                          if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "choice", $2, 0)) {
                                            YYABORT;
                                          }
                                        } else {
                                          $$ = $1;
                                        }
                                      }
  |  choice_opt_stmt description_stmt { if (read_all) {
                                          if (yang_read_description(trg, $1.choice.ptr_choice, s, "choice")) {
                                            free($1.choice.s);
                                            YYABORT;
                                          }
                                          s = NULL;
                                          $$ = $1;
                                        }
                                      }
  |  choice_opt_stmt reference_stmt { if (read_all) {
                                        if (yang_read_reference(trg, $1.choice.ptr_choice, s, "choice")) {
                                          free($1.choice.s);
                                          YYABORT;
                                        }
                                        s = NULL;
                                        $$ = $1;
                                      }
                                    }
  |  choice_opt_stmt short_case_case_stmt { actual = $1.choice.ptr_choice;
                                            actual_type = CHOICE_KEYWORD;
                                            data_node = actual;
                                            if (read_all && data_node->parent && (data_node->parent->nodetype == LYS_GROUPING)) {
                                              data_node = NULL;
                                            }
                                          }
     stmtsep { $$ = $1; }
  ;

short_case_case_stmt:  short_case_stmt
  |  case_stmt
  ;

short_case_stmt: container_stmt
  |  leaf_stmt
  |  leaf_list_stmt
  |  list_stmt
  |  anyxml_stmt
  ;

case_stmt: CASE_KEYWORD sep identifier_arg_str { if (read_all) {
                                                   if (!(actual = yang_read_node(trg,actual,s,LYS_CASE,sizeof(struct lys_node_case)))) {YYABORT;}
                                                   data_node = actual;
                                                   s=NULL;
                                                 }
                                               }
           case_end;

case_end: ';'
  |  '{' stmtsep
         case_opt_stmt
      '}' ;

case_opt_stmt: %empty { if (read_all) {
                          $$.cs = actual;
                          actual_type = CASE_KEYWORD;
                          if (size_arrays->node[size_arrays->next].if_features) {
                            $$.cs->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.cs->features);
                            if (!$$.cs->features) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                          store_flags((struct lys_node *)$$.cs, size_arrays->node[size_arrays->next].flags, 1);
                          size_arrays->next++;
                        } else {
                          $$.index = size_arrays->size;
                          if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                            LOGMEM;
                            YYABORT;
                          }
                        }
                      }
  |  case_opt_stmt when_stmt { actual = $1.cs; actual_type = CASE_KEYWORD; }
     stmtsep
  |  case_opt_stmt if_feature_stmt { if (read_all) {
                                       if (yang_read_if_feature(trg, $1.cs, s, unres, CASE_KEYWORD)) {YYABORT;}
                                       s=NULL;
                                     } else {
                                       size_arrays->node[$1.index].if_features++;
                                     }
                                   }
  |  case_opt_stmt status_read_stmt { if (!read_all) {
                                        if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "case", $2, 0)) {
                                          YYABORT;
                                        }
                                      }
                                    }
  |  case_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.cs, s, "case")) {
                                        YYABORT;
                                      }
                                      s = NULL;
                                    }
  |  case_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.cs, s, "case")) {
                                      YYABORT;
                                    }
                                    s = NULL;
                                  }
  |  case_opt_stmt data_def_stmt { actual = $1.cs;
                                   actual_type = CASE_KEYWORD;
                                   data_node = actual;
                                 }
     stmtsep
  ;

anyxml_stmt: ANYXML_KEYWORD sep identifier_arg_str { if (read_all) {
                                                       if (!(actual = yang_read_node(trg,actual,s,LYS_ANYXML,sizeof(struct lys_node_anyxml)))) {YYABORT;}
                                                       data_node = actual;
                                                       if (data_node->parent && (data_node->parent->nodetype == LYS_GROUPING)) {
                                                         data_node = NULL;
                                                       }
                                                       s=NULL;
                                                     }
                                                   }
             anyxml_end;

anyxml_end: ';'
  |  '{' stmtsep
         anyxml_opt_stmt
     '}' ;

anyxml_opt_stmt: %empty { if (read_all) {
                            $$.anyxml = actual;
                            actual_type = ANYXML_KEYWORD;
                            if (size_arrays->node[size_arrays->next].if_features) {
                              $$.anyxml->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.anyxml->features);
                              if (!$$.anyxml->features) {
                                LOGMEM;
                                YYABORT;
                              }
                            }
                            if (size_arrays->node[size_arrays->next].must) {
                              $$.anyxml->must = calloc(size_arrays->node[size_arrays->next].must, sizeof *$$.anyxml->must);
                              if (!$$.anyxml->features || !$$.anyxml->must) {
                                LOGMEM;
                                YYABORT;
                              }
                            }
                            store_flags((struct lys_node *)$$.anyxml, size_arrays->node[size_arrays->next].flags, config_inherit);
                            size_arrays->next++;
                          } else {
                            $$.index = size_arrays->size;
                            if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                        }
  |  anyxml_opt_stmt when_stmt { actual = $1.anyxml; actual_type = ANYXML_KEYWORD; }
     stmtsep
  |  anyxml_opt_stmt if_feature_stmt { if (read_all) {
                                         if (yang_read_if_feature(trg, $1.anyxml, s, unres, ANYXML_KEYWORD)) {YYABORT;}
                                         s=NULL;
                                       } else {
                                         size_arrays->node[$1.index].if_features++;
                                       }
                                     }
  |  anyxml_opt_stmt must_stmt { if (read_all) {
                                   actual = $1.anyxml;
                                   actual_type = ANYXML_KEYWORD;
                                 } else {
                                   size_arrays->node[$1.index].must++;
                                 }
                               }
     stmtsep
  |  anyxml_opt_stmt config_read_stmt { if (!read_all) {
                                          if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_CONFIG_MASK, "config", "anyxml", $2, 0)) {
                                            YYABORT;
                                          }
                                        }
                                      }
  |  anyxml_opt_stmt mandatory_read_stmt { if (!read_all) {
                                             if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_MAND_MASK, "mandatory", "anyxml", $2, 0)) {
                                               YYABORT;
                                             }
                                           }
                                         }
  |  anyxml_opt_stmt status_read_stmt { if (!read_all) {
                                          if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "anyxml", $2, 0)) {
                                            YYABORT;
                                          }
                                        }
                                      }
  |  anyxml_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.anyxml, s, "anyxml")) {
                                          YYABORT;
                                        }
                                        s = NULL;
                                      }
  |  anyxml_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.anyxml, s, "anyxml")) {
                                        YYABORT;
                                      }
                                      s = NULL;
                                    }

uses_stmt: USES_KEYWORD sep identifier_ref_arg_str { if (read_all) {
                                                       if (!(actual = yang_read_node(trg,actual,s,LYS_USES,sizeof(struct lys_node_uses)))) {YYABORT;}
                                                       data_node = actual;
                                                       if (data_node->parent && (data_node->parent->nodetype == LYS_GROUPING)) {
                                                         data_node = NULL;
                                                       }
                                                       s=NULL;
                                                     }
                                                   }
           uses_end { if (read_all) {
                        if (unres_schema_add_node(trg, unres, actual, UNRES_USES, NULL) == -1) {
                          YYABORT;
                        }
                      }
                    }

uses_end: ';'
  |  '{' stmtsep
         uses_opt_stmt
     '}' ;

uses_opt_stmt: %empty { if (read_all) {
                          $$.uses.ptr_uses = actual;
                          $$.uses.config_inherit = config_inherit;
                          actual_type = USES_KEYWORD;
                          if (size_arrays->node[size_arrays->next].if_features) {
                            $$.uses.ptr_uses->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.uses.ptr_uses->features);
                            if (!$$.uses.ptr_uses->features) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                          if (size_arrays->node[size_arrays->next].refine) {
                            $$.uses.ptr_uses->refine = calloc(size_arrays->node[size_arrays->next].refine, sizeof *$$.uses.ptr_uses->refine);
                            if (!$$.uses.ptr_uses->refine) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                          if (size_arrays->node[size_arrays->next].augment) {
                            $$.uses.ptr_uses->augment = calloc(size_arrays->node[size_arrays->next].augment, sizeof *$$.uses.ptr_uses->augment);
                            if (!$$.uses.ptr_uses->augment) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                          store_flags((struct lys_node *)$$.uses.ptr_uses, size_arrays->node[size_arrays->next].flags, config_inherit);
                          size_arrays->next++;
                        } else {
                          $$.index = size_arrays->size;
                          if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                            LOGMEM;
                            YYABORT;
                          }
                        }
                      }
  |  uses_opt_stmt when_stmt { actual = $1.uses.ptr_uses; actual_type = USES_KEYWORD; }
     stmtsep
  |  uses_opt_stmt if_feature_stmt { if (read_all) {
                                       if (yang_read_if_feature(trg, $1.uses.ptr_uses, s, unres, USES_KEYWORD)) {YYABORT;}
                                       s=NULL;
                                     } else {
                                       size_arrays->node[$1.index].if_features++;
                                     }
                                   }
  |  uses_opt_stmt status_read_stmt { if (!read_all) {
                                        if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "uses", $2, 0)) {
                                          YYABORT;
                                        }
                                      }
                                    }
  |  uses_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.uses.ptr_uses, s, "uses")) {
                                        YYABORT;
                                      }
                                      s = NULL;
                                    }
  |  uses_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.uses.ptr_uses, s, "uses")) {
                                      YYABORT;
                                    }
                                    s = NULL;
                                  }
  |  uses_opt_stmt refine_stmt { if (read_all) {
                                   actual = $1.uses.ptr_uses;
                                   actual_type = USES_KEYWORD;
                                 } else {
                                   size_arrays->node[$1.index].refine++;
                                 }
                               }
     stmtsep
  |  uses_opt_stmt uses_augment_stmt { if (read_all) {
                                         actual = $1.uses.ptr_uses;
                                         actual_type = USES_KEYWORD;
                                         data_node = actual;
                                         if (data_node->parent && (data_node->parent->nodetype == LYS_GROUPING)) {
                                           data_node = NULL;
                                         }
                                         config_inherit = $1.uses.config_inherit;
                                       } else {
                                         size_arrays->node[$1.index].augment++;
                                       }
                                     }
     stmtsep
  ;

refine_stmt: REFINE_KEYWORD sep refine_arg_str { if (read_all) {
                                                   if (!(actual = yang_read_refine(trg, actual, s))) {
                                                     YYABORT;
                                                   }
                                                   s = NULL;
                                                 }
                                               }
             refine_end;

refine_end: ';'
  |  '{' stmtsep
         refine_body_opt_stmts
     '}' ;


refine_arg_str: descendant_schema_nodeid optsep
  | string_1
  ;

refine_body_opt_stmts: %empty { if (read_all) {
                                  $$.refine = actual;
                                  actual_type = REFINE_KEYWORD;
                                  if (size_arrays->node[size_arrays->next].must) {
                                    $$.refine->must = calloc(size_arrays->node[size_arrays->next].must, sizeof *$$.refine->must);
                                    if (!$$.refine->must) {
                                      LOGMEM;
                                      YYABORT;
                                    }
                                    $$.refine->target_type = LYS_LIST | LYS_LEAFLIST | LYS_CONTAINER | LYS_ANYXML;
                                  }
                                  size_arrays->next++;
                                } else {
                                  $$.index = size_arrays->size;
                                  if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                                    LOGMEM;
                                    YYABORT;
                                  }
                                }
                              }
  |  refine_body_opt_stmts must_stmt stmtsep { if (read_all) {
                                         actual = $1.refine;
                                         actual_type = REFINE_KEYWORD;
                                       } else {
                                         size_arrays->node[$1.index].must++;
                                       }
                                     }
  |  refine_body_opt_stmts presence_stmt { if (read_all) {
                                             if ($1.refine->target_type) {
                                               if ($1.refine->target_type & LYS_CONTAINER) {
                                                 if ($1.refine->mod.presence) {
                                                   LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "presence", "refine");
                                                   free(s);
                                                   YYABORT;
                                                 }
                                                 $1.refine->target_type = LYS_CONTAINER;
                                                 $1.refine->mod.presence = lydict_insert_zc(trg->ctx, s);
                                               } else {
                                                 free(s);
                                                 LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "presence", "refine");
                                                 LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid refine target nodetype for the substatements.");
                                                 YYABORT;
                                               }
                                             } else {
                                               $1.refine->target_type = LYS_CONTAINER;
                                               $1.refine->mod.presence = lydict_insert_zc(trg->ctx, s);
                                             }
                                             s = NULL;
                                             $$ = $1;
                                           }
                                         }
  |  refine_body_opt_stmts default_stmt { if (read_all) {
                                            if ($1.refine->target_type) {
                                              if ($1.refine->target_type & (LYS_LEAF | LYS_CHOICE)) {
                                                $1.refine->target_type &= (LYS_LEAF | LYS_CHOICE);
                                                if ($1.refine->mod.dflt) {
                                                  LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "default", "refine");
                                                  free(s);
                                                  YYABORT;
                                                }
                                                $1.refine->mod.dflt = lydict_insert_zc(trg->ctx, s);
                                              } else {
                                                free(s);
                                                LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "default", "refine");
                                                LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid refine target nodetype for the substatements.");
                                                YYABORT;
                                              }
                                            } else {
                                              $1.refine->target_type = LYS_LEAF | LYS_CHOICE;
                                              $1.refine->mod.dflt = lydict_insert_zc(trg->ctx, s);
                                            }
                                            s = NULL;
                                            $$ = $1;
                                          }
                                        }
  |  refine_body_opt_stmts config_stmt { if (read_all) {
                                           if ($1.refine->target_type) {
                                             if ($1.refine->target_type & (LYS_LEAF | LYS_CHOICE | LYS_LIST | LYS_CONTAINER | LYS_LEAFLIST)) {
                                               $1.refine->target_type &= (LYS_LEAF | LYS_CHOICE | LYS_LIST | LYS_CONTAINER | LYS_LEAFLIST);
                                               if (yang_check_flags((uint16_t*)&$1.refine->flags, LYS_CONFIG_MASK, "config", "refine", $2, 1)) {
                                                 YYABORT;
                                               }
                                             } else {
                                               LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "config", "refine");
                                               LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid refine target nodetype for the substatements.");
                                               YYABORT;
                                             }
                                           } else {
                                             $1.refine->target_type = LYS_LEAF | LYS_CHOICE | LYS_LIST | LYS_CONTAINER | LYS_LEAFLIST;
                                             $1.refine->flags |= $2;
                                           }
                                           $$ = $1;
                                         }
                                       }
  |  refine_body_opt_stmts mandatory_stmt { if (read_all) {
                                              if ($1.refine->target_type) {
                                                if ($1.refine->target_type & (LYS_LEAF | LYS_CHOICE | LYS_ANYXML)) {
                                                  $1.refine->target_type &= (LYS_LEAF | LYS_CHOICE | LYS_ANYXML);
                                                  if (yang_check_flags((uint16_t*)&$1.refine->flags, LYS_MAND_MASK, "mandatory", "refine", $2, 1)) {
                                                    YYABORT;
                                                  }
                                                } else {
                                                  LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "mandatory", "refine");
                                                  LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid refine target nodetype for the substatements.");
                                                  YYABORT;
                                                }
                                              } else {
                                                $1.refine->target_type = LYS_LEAF | LYS_CHOICE | LYS_ANYXML;
                                                $1.refine->flags |= $2;
                                              }
                                              $$ = $1;
                                            }
                                          }
  |  refine_body_opt_stmts min_elements_stmt { if (read_all) {
                                                 if ($1.refine->target_type) {
                                                   if ($1.refine->target_type & (LYS_LIST | LYS_LEAFLIST)) {
                                                     $1.refine->target_type &= (LYS_LIST | LYS_LEAFLIST);
                                                     if ($1.refine->flags & LYS_RFN_MINSET) {
                                                       LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "min-elements", "refine");
                                                       YYABORT;
                                                     }
                                                     $1.refine->flags |= LYS_RFN_MINSET;
                                                     $1.refine->mod.list.min = $2;
                                                   } else {
                                                     LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "min-elements", "refine");
                                                     LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid refine target nodetype for the substatements.");
                                                     YYABORT;
                                                   }
                                                 } else {
                                                   $1.refine->target_type = LYS_LIST | LYS_LEAFLIST;
                                                   $1.refine->flags |= LYS_RFN_MINSET;
                                                   $1.refine->mod.list.min = $2;
                                                 }
                                                 $$ = $1;
                                               }
                                             }
  |  refine_body_opt_stmts max_elements_stmt { if (read_all) {
                                                 if ($1.refine->target_type) {
                                                   if ($1.refine->target_type & (LYS_LIST | LYS_LEAFLIST)) {
                                                     $1.refine->target_type &= (LYS_LIST | LYS_LEAFLIST);
                                                     if ($1.refine->flags & LYS_RFN_MAXSET) {
                                                       LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "max-elements", "refine");
                                                       YYABORT;
                                                     }
                                                     $1.refine->flags |= LYS_RFN_MAXSET;
                                                     $1.refine->mod.list.max = $2;
                                                   } else {
                                                     LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "max-elements", "refine");
                                                     LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Invalid refine target nodetype for the substatements.");
                                                     YYABORT;
                                                   }
                                                 } else {
                                                   $1.refine->target_type = LYS_LIST | LYS_LEAFLIST;
                                                   $1.refine->flags |= LYS_RFN_MAXSET;
                                                   $1.refine->mod.list.max = $2;
                                                 }
                                                 $$ = $1;
                                               }
                                             }
  |  refine_body_opt_stmts description_stmt { if (read_all && yang_read_description(trg, $1.refine, s, "refine")) {
                                                YYABORT;
                                              }
                                              s = NULL;
                                            }
  |  refine_body_opt_stmts reference_stmt { if (read_all && yang_read_reference(trg, $1.refine, s, "refine")) {
                                              YYABORT;
                                            }
                                            s = NULL;
                                          }

uses_augment_stmt: AUGMENT_KEYWORD sep uses_augment_arg_str { if (read_all) {
                                                                if (!(actual = yang_read_augment(trg, actual, s))) {
                                                                  YYABORT;
                                                                }
                                                                data_node = actual;
                                                                s = NULL;
                                                              }
                                                            }
                   '{' stmtsep
                       augment_opt_stmt { if (read_all && !($7.node.flag & LYS_DATADEF)){
                                            LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "data-def or case", "uses/augment");
                                            YYABORT;
                                          }
                                        }
                   '}' ;

uses_augment_arg_str: descendant_schema_nodeid optsep
  |  string_1
  ;

augment_stmt: AUGMENT_KEYWORD sep augment_arg_str { if (read_all) {
                                                      if (!(actual = yang_read_augment(trg, NULL, s))) {
                                                        YYABORT;
                                                      }
                                                      data_node = actual;
                                                      s = NULL;
                                                    }
                                                  }
              '{' stmtsep
                  augment_opt_stmt { if (read_all) {
                                       if (!($7.node.flag & LYS_DATADEF)){
                                         LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "data-def or case", "augment");
                                         YYABORT;
                                       }
                                       if (unres_schema_add_node(trg, unres, actual, UNRES_AUGMENT, NULL) == -1) {
                                         YYABORT;
                                       }
                                     }
                                   }
               '}' ;

augment_opt_stmt: %empty { if (read_all) {
                             $$.node.ptr_augment = actual;
                             $$.node.flag = 0;
                             actual_type = AUGMENT_KEYWORD;
                             if (size_arrays->node[size_arrays->next].if_features) {
                               $$.node.ptr_augment->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.node.ptr_augment->features);
                               if (!$$.node.ptr_augment->features) {
                                 LOGMEM;
                                 YYABORT;
                               }
                             }
                             config_inherit = DISABLE_INHERIT;
                             size_arrays->next++;
                           } else {
                             $$.index = size_arrays->size;
                             if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                               LOGMEM;
                               YYABORT;
                             }
                           }
                         }
  |  augment_opt_stmt when_stmt { actual = $1.node.ptr_augment; actual_type = AUGMENT_KEYWORD; }
     stmtsep
  |  augment_opt_stmt if_feature_stmt { if (read_all) {
                                          if (yang_read_if_feature(trg, $1.node.ptr_augment, s, unres, AUGMENT_KEYWORD)) {YYABORT;}
                                          s=NULL;
                                        } else {
                                          size_arrays->node[$1.index].if_features++;
                                        }
                                      }
  |  augment_opt_stmt status_stmt { if (read_all) {
                                      /* hack - flags is bit field, so its address is taken as a member after
                                       * 3 const char pointers in the lys_node_augment structure */
                                      if (yang_check_flags((uint16_t*)((const char **)$1.node.ptr_augment + 3),
                                                           LYS_STATUS_MASK, "status", "augment", $2, 0)) {
                                        YYABORT;
                                      }
                                    }
                                  }
  |  augment_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.node.ptr_augment, s, "augment")) {
                                           YYABORT;
                                         }
                                         s = NULL;
                                       }
  |  augment_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.node.ptr_augment, s, "augment")) {
                                         YYABORT;
                                       }
                                       s = NULL;
                                     }
  |  augment_opt_stmt data_def_stmt { if (read_all) {
                                        actual = $1.node.ptr_augment;
                                        actual_type = AUGMENT_KEYWORD;
                                        $1.node.flag |= LYS_DATADEF;
                                        data_node = actual;
                                      }
                                    }
     stmtsep { $$ = $1; }
  |  augment_opt_stmt case_stmt { if (read_all) {
                                    actual = $1.node.ptr_augment;
                                    actual_type = AUGMENT_KEYWORD;
                                    $1.node.flag |= LYS_DATADEF;
                                    data_node = actual;
                                  }
                                }
     stmtsep { $$ = $1; }
  ;

augment_arg_str: absolute_schema_nodeids optsep
  |  string_1
  ;

rpc_stmt: RPC_KEYWORD sep identifier_arg_str { if (read_all) {
                                                 if (!(actual = yang_read_node(trg, NULL, s, LYS_RPC, sizeof(struct lys_node_rpc)))) {
                                                   YYABORT;
                                                 }
                                                 data_node = actual;
                                                 s = NULL;
                                               }
                                               config_inherit = DISABLE_INHERIT;
                                             }
          rpc_end { config_inherit = ENABLE_INHERIT; }

rpc_end: ';'
  |  '{' stmtsep
         rpc_opt_stmt
      '}'


rpc_opt_stmt: %empty { if (read_all) {
                         $$.node.ptr_rpc = actual;
                         $$.node.flag = 0;
                         actual_type = RPC_KEYWORD;
                         if (size_arrays->node[size_arrays->next].if_features) {
                           $$.node.ptr_rpc->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.node.ptr_rpc->features);
                           if (!$$.node.ptr_rpc->features) {
                             LOGMEM;
                             YYABORT;
                           }
                         }
                         if (size_arrays->node[size_arrays->next].tpdf) {
                           $$.node.ptr_rpc->tpdf = calloc(size_arrays->node[size_arrays->next].tpdf, sizeof *$$.node.ptr_rpc->tpdf);
                           if (!$$.node.ptr_rpc->tpdf) {
                             LOGMEM;
                             YYABORT;
                           }
                         }
                         store_flags((struct lys_node *)$$.node.ptr_rpc, size_arrays->node[size_arrays->next].flags, 0);
                         size_arrays->next++;
                       } else {
                         $$.index = size_arrays->size;
                         if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                           LOGMEM;
                           YYABORT;
                         }
                       }
                     }
  |  rpc_opt_stmt if_feature_stmt { if (read_all) {
                                      if (yang_read_if_feature(trg, $1.node.ptr_rpc, s, unres, RPC_KEYWORD)) {YYABORT;}
                                      s=NULL;
                                    } else {
                                      size_arrays->node[$1.index].if_features++;
                                    }
                                  }
  |  rpc_opt_stmt status_read_stmt { if (!read_all) {
                                       if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "rpc", $2, 0)) {
                                         YYABORT;
                                       }
                                     }
                                   }
  |  rpc_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.node.ptr_rpc, s, "rpc")) {
                                       YYABORT;
                                     }
                                     s = NULL;
                                   }
  |  rpc_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.node.ptr_rpc, s, "rpc")) {
                                     YYABORT;
                                   }
                                   s = NULL;
                                 }
  |  rpc_opt_stmt typedef_stmt { if (read_all) {
                                           actual = $1.node.ptr_rpc;
                                           actual_type = RPC_KEYWORD;
                                         } else {
                                           size_arrays->node[$1.index].tpdf++;
                                         }
                                       }
     stmtsep
  |  rpc_opt_stmt grouping_stmt { actual = $1.node.ptr_rpc;
                                  actual_type = RPC_KEYWORD;
                                  data_node = actual;
                                }
     stmtsep
  |  rpc_opt_stmt input_stmt { if (read_all) {
                                 if ($1.node.flag & LYS_RPC_INPUT) {
                                   LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_rpc, "input", "rpc");
                                   YYABORT;
                                 }
                                 $1.node.flag |= LYS_RPC_INPUT;
                                 actual = $1.node.ptr_rpc;
                                 actual_type = RPC_KEYWORD;
                                 data_node = actual;
                               }
                             }
     stmtsep { $$ = $1; }
  |  rpc_opt_stmt output_stmt { if (read_all) {
                                  if ($1.node.flag & LYS_RPC_OUTPUT) {
                                    LOGVAL(LYE_TOOMANY, LY_VLOG_LYS, $1.node.ptr_rpc, "output", "rpc");
                                    YYABORT;
                                  }
                                  $1.node.flag |= LYS_RPC_OUTPUT;
                                  actual = $1.node.ptr_rpc;
                                  actual_type = RPC_KEYWORD;
                                  data_node = actual;
                                }
                              }
     stmtsep { $$ = $1; }

input_stmt: INPUT_KEYWORD optsep { if (read_all) {
                                     s = strdup("input");
                                     if (!s) {
                                       LOGMEM;
                                       YYABORT;
                                     }
                                     if (!(actual = yang_read_node(trg, actual, s, LYS_INPUT, sizeof(struct lys_node_rpc_inout)))) {
                                      YYABORT;
                                     }
                                     data_node = actual;
                                     s = NULL;
                                   }
                                 }
            '{' stmtsep
                input_output_opt_stmt { if (read_all && !($6.node.flag & LYS_DATADEF)) {
                                          LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, "data-def", "input");
                                          YYABORT;
                                        }
                                      }
            '}'

input_output_opt_stmt: %empty { if (read_all) {
                                  $$.node.ptr_inout = actual;
                                  $$.node.flag = 0;
                                  actual_type = INPUT_KEYWORD;
                                  if (size_arrays->node[size_arrays->next].tpdf) {
                                    $$.node.ptr_inout->tpdf = calloc(size_arrays->node[size_arrays->next].tpdf, sizeof *$$.node.ptr_inout->tpdf);
                                    if (!$$.node.ptr_inout->tpdf) {
                                      LOGMEM;
                                      YYABORT;
                                    }
                                  }
                                  size_arrays->next++;
                                } else {
                                  $$.index = size_arrays->size;
                                  if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                                    LOGMEM;
                                    YYABORT;
                                  }
                                }
                              }
  |  input_output_opt_stmt typedef_stmt { if (read_all) {
                                                    actual = $1.node.ptr_inout;
                                                    actual_type = INPUT_KEYWORD;
                                                  } else {
                                                    size_arrays->node[$1.index].tpdf++;
                                                  }
                                                }
     stmtsep
  |  input_output_opt_stmt grouping_stmt { actual = $1.node.ptr_inout;
                                           actual_type = INPUT_KEYWORD;
                                           data_node = actual;
                                         }
     stmtsep
  |  input_output_opt_stmt data_def_stmt { if (read_all) {
                                             actual = $1.node.ptr_inout;
                                             actual_type = INPUT_KEYWORD;
                                             $1.node.flag |= LYS_DATADEF;
                                             data_node = actual;
                                           }
                                         }
     stmtsep { $$ = $1; }
  ;

output_stmt: OUTPUT_KEYWORD optsep { if (read_all) {
                                       s = strdup("output");
                                       if (!s) {
                                         LOGMEM;
                                         YYABORT;
                                       }
                                       if (!(actual = yang_read_node(trg, actual, s, LYS_OUTPUT, sizeof(struct lys_node_rpc_inout)))) {
                                        YYABORT;
                                       }
                                       data_node = actual;
                                       s = NULL;
                                     }
                                   }
             '{' stmtsep
                 input_output_opt_stmt { if (read_all && !($6.node.flag & LYS_DATADEF)) {
                                           LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, "data-def", "output");
                                           YYABORT;
                                         }
                                       }
             '}'

notification_stmt: NOTIFICATION_KEYWORD sep identifier_arg_str { if (read_all) {
                                                                   if (!(actual = yang_read_node(trg, NULL, s, LYS_NOTIF, sizeof(struct lys_node_notif)))) {
                                                                    YYABORT;
                                                                   }
                                                                   data_node = actual;
                                                                 }
                                                                 config_inherit = DISABLE_INHERIT;
                                                               }
                   notification_end { config_inherit = ENABLE_INHERIT; }

notification_end: ';' { if (read_all) {
                          size_arrays->next++;
                        }
                      }
  |  '{' stmtsep
         notification_opt_stmt
      '}' ;


notification_opt_stmt: %empty { if (read_all) {
                                  $$.notif = actual;
                                  actual_type = NOTIFICATION_KEYWORD;
                                  if (size_arrays->node[size_arrays->next].if_features) {
                                    $$.notif->features = calloc(size_arrays->node[size_arrays->next].if_features, sizeof *$$.notif->features);
                                    if (!$$.notif->features) {
                                      LOGMEM;
                                      YYABORT;
                                    }
                                  }
                                  if (size_arrays->node[size_arrays->next].tpdf) {
                                    $$.notif->tpdf = calloc(size_arrays->node[size_arrays->next].tpdf, sizeof *$$.notif->tpdf);
                                    if (!$$.notif->tpdf) {
                                      LOGMEM;
                                      YYABORT;
                                    }
                                  }
                                  store_flags((struct lys_node *)$$.notif, size_arrays->node[size_arrays->next].flags, 0);
                                  size_arrays->next++;
                                } else {
                                  $$.index = size_arrays->size;
                                  if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                                    LOGMEM;
                                    YYABORT;
                                  }
                                }
                              }
  |  notification_opt_stmt if_feature_stmt { if (read_all) {
                                               if (yang_read_if_feature(trg, $1.notif, s, unres, NOTIFICATION_KEYWORD)) {YYABORT;}
                                               s=NULL;
                                             } else {
                                               size_arrays->node[$1.index].if_features++;
                                             }
                                           }
  |  notification_opt_stmt status_read_stmt { if (!read_all) {
                                                if (yang_check_flags(&size_arrays->node[$1.index].flags, LYS_STATUS_MASK, "status", "notification", $2, 0)) {
                                                  YYABORT;
                                                }
                                              }
                                            }
  |  notification_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.notif, s, "notification")) {
                                                YYABORT;
                                              }
                                              s = NULL;
                                            }
  |  notification_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.notif, s, "notification")) {
                                              YYABORT;
                                            }
                                            s = NULL;
                                          }
  |  notification_opt_stmt typedef_stmt { if (read_all) {
                                                    actual = $1.notif;
                                                    actual_type = NOTIFICATION_KEYWORD;
                                                  } else {
                                                    size_arrays->node[$1.index].tpdf++;
                                                  }
                                                }
     stmtsep
  |  notification_opt_stmt grouping_stmt { actual = $1.notif;
                                           actual_type = NOTIFICATION_KEYWORD;
                                           data_node = actual;
                                         }
     stmtsep
  |  notification_opt_stmt data_def_stmt { actual = $1.notif;
                                           actual_type = NOTIFICATION_KEYWORD;
                                           data_node = actual;
                                         }
     stmtsep
  ;

deviation_stmt: DEVIATION_KEYWORD sep deviation_arg_str { if (read_all) {
                                                            if (!(actual = yang_read_deviation(trg, s))) {
                                                              YYABORT;
                                                            }
                                                            s = NULL;
                                                            trg->deviation_size++;
                                                            }
                                                        }
                '{' stmtsep
                    deviation_opt_stmt  { if (read_all) {
                                            if (actual_type == DEVIATION_KEYWORD) {
                                              LOGVAL(LYE_MISSCHILDSTMT, LY_VLOG_NONE, NULL, "deviate", "deviation");
                                              YYABORT;
                                            }
                                            if (yang_check_deviation(trg, actual, unres)) {
                                              YYABORT;
                                            }
                                            free($7.deviation);
                                          }
                                        }
                '}'

deviation_opt_stmt: %empty { if (read_all) {
                               $$.deviation = actual;
                               actual_type = DEVIATION_KEYWORD;
                               if (size_arrays->node[size_arrays->next].deviate) {
                                 $$.deviation->deviation->deviate = calloc(size_arrays->node[size_arrays->next].deviate, sizeof *$$.deviation->deviation->deviate);
                                 if (!$$.deviation->deviation->deviate) {
                                   LOGMEM;
                                   YYABORT;
                                 }
                               }
                               size_arrays->next++;
                             } else {
                               $$.index = size_arrays->size;
                               if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                                 LOGMEM;
                                 YYABORT;
                               }
                             }
                           }
  |  deviation_opt_stmt description_stmt { if (read_all && yang_read_description(trg, $1.deviation->deviation, s, "deviation")) {
                                             free($1.deviation);
                                             YYABORT;
                                           }
                                           s = NULL;
                                           $$ = $1;
                                         }
  |  deviation_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, $1.deviation->deviation, s, "deviation")) {
                                           free($1.deviation);
                                           YYABORT;
                                         }
                                         s = NULL;
                                         $$ = $1;
                                       }
  |  deviation_opt_stmt DEVIATE_KEYWORD sep deviate_body_stmt { if (read_all) {
                                                                  actual = $1.deviation;
                                                                  actual_type = DEVIATE_KEYWORD;
                                                                  $$ = $1;
                                                                } else {
                                                                  /* count of deviate statemenet */
                                                                  size_arrays->node[$1.index].deviate++;
                                                                }
                                                              }

deviation_arg_str: absolute_schema_nodeids optsep
  | string_1

deviate_body_stmt: deviate_not_supported_stmt
                   { if (read_all && yang_read_deviate_unsupported(actual)) {
                       YYABORT;
                     }
                   }
  |  deviate_stmts optsep

deviate_stmts: deviate_add_stmt
  |  deviate_replace_stmt
  |  deviate_delete_stmt
  ;

deviate_not_supported_stmt: NOT_SUPPORTED_KEYWORD optsep stmtend;

deviate_add_stmt: ADD_KEYWORD optsep { if (read_all && yang_read_deviate(actual, LY_DEVIATE_ADD)) {
                                         YYABORT;
                                       }
                                     }
                  deviate_add_end

deviate_add_end: ';'
  |  '{' stmtsep
         deviate_add_opt_stmt
     '}'

deviate_add_opt_stmt: %empty { if (read_all) {
                                 $$.deviation = actual;
                                 actual_type = ADD_KEYWORD;
                                 if (size_arrays->node[size_arrays->next].must) {
                                    if (yang_read_deviate_must(actual, size_arrays->node[size_arrays->next].must)) {
                                      YYABORT;
                                    }
                                  }
                                  if (size_arrays->node[size_arrays->next].unique) {
                                    if (yang_read_deviate_unique(actual, size_arrays->node[size_arrays->next].unique)) {
                                      YYABORT;
                                    }
                                  }
                                  size_arrays->next++;
                               } else {
                                 $$.index = size_arrays->size;
                                 if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                                   LOGMEM;
                                   YYABORT;
                                 }
                               }
                             }
  |  deviate_add_opt_stmt units_stmt { if (read_all) {
                                         if (yang_read_deviate_units(trg->ctx, $1.deviation, s)) {
                                           YYABORT;
                                         }
                                         s = NULL;
                                         $$ = $1;
                                       }
                                     }
  |  deviate_add_opt_stmt must_stmt stmtsep { if (read_all) {
                                        actual = $1.deviation;
                                        actual_type = ADD_KEYWORD;
                                        $$ = $1;
                                      } else {
                                        size_arrays->node[$1.index].must++;
                                      }
                                    }
  |  deviate_add_opt_stmt unique_stmt { if (read_all) {
                                          struct lys_node_list *list;

                                          list = (struct lys_node_list *)$1.deviation->target;
                                          if (yang_fill_unique(trg, list, &list->unique[list->unique_size], s, NULL)) {
                                            list->unique_size++;
                                            YYABORT;
                                          }
                                          list->unique_size++;
                                          free(s);
                                          s = NULL;
                                          $$ = $1;
                                        } else {
                                          size_arrays->node[$1.index].unique++;
                                        }
                                      }
  |  deviate_add_opt_stmt default_stmt { if (read_all) {
                                           if (yang_read_deviate_default(trg->ctx, $1.deviation, s)) {
                                             YYABORT;
                                           }
                                           s = NULL;
                                           $$ = $1;
                                         }
                                       }
  |  deviate_add_opt_stmt config_stmt { if (read_all) {
                                          if (yang_read_deviate_config($1.deviation, $2)) {
                                            YYABORT;
                                          }
                                          $$ = $1;
                                        }
                                      }
  |  deviate_add_opt_stmt mandatory_stmt { if (read_all) {
                                             if (yang_read_deviate_mandatory($1.deviation, $2)) {
                                               YYABORT;
                                             }
                                             $$ = $1;
                                           }
                                         }
  |  deviate_add_opt_stmt min_elements_stmt { if (read_all) {
                                                if ($1.deviation->deviate->min_set) {
                                                  LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "min-elements", "deviation");
                                                  YYABORT;
                                                }
                                                if (yang_read_deviate_minmax($1.deviation, $2, 0)) {
                                                  YYABORT;
                                                }
                                                $$ =  $1;
                                              }
                                            }
  |  deviate_add_opt_stmt max_elements_stmt { if (read_all) {
                                                if ($1.deviation->deviate->max_set) {
                                                  LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "max-elements", "deviation");
                                                  YYABORT;
                                                }
                                                if (yang_read_deviate_minmax($1.deviation, $2, 1)) {
                                                  YYABORT;
                                                }
                                                $$ =  $1;
                                              }
                                            }

deviate_delete_stmt: DELETE_KEYWORD optsep { if (read_all && yang_read_deviate(actual, LY_DEVIATE_DEL)) {
                                               YYABORT;
                                             }
                                           }
                     deviate_delete_end

deviate_delete_end: ';'
  |  '{' stmtsep
         deviate_delete_opt_stmt
      '}' ;

deviate_delete_opt_stmt: %empty { if (read_all) {
                                    $$.deviation = actual;
                                    actual_type = DELETE_KEYWORD;
                                    if (size_arrays->node[size_arrays->next].must) {
                                      if (yang_read_deviate_must(actual, size_arrays->node[size_arrays->next].must)) {
                                        YYABORT;
                                      }
                                    }
                                    if (size_arrays->node[size_arrays->next].unique) {
                                      if (yang_read_deviate_unique(actual, size_arrays->node[size_arrays->next].unique)) {
                                        YYABORT;
                                      }
                                    }
                                    size_arrays->next++;
                                  } else {
                                    $$.index = size_arrays->size;
                                    if (yang_add_elem(&size_arrays->node, &size_arrays->size)) {
                                      LOGMEM;
                                      YYABORT;
                                    }
                                  }
                                }
  |  deviate_delete_opt_stmt units_stmt { if (read_all) {
                                            if (yang_read_deviate_units(trg->ctx, $1.deviation, s)) {
                                              YYABORT;
                                            }
                                            s = NULL;
                                            $$ = $1;
                                          }
                                        }
  |  deviate_delete_opt_stmt must_stmt stmtsep { if (read_all) {
                                           if (yang_check_deviate_must(trg->ctx, $1.deviation)) {
                                             YYABORT;
                                           }
                                           actual = $1.deviation;
                                           actual_type = DELETE_KEYWORD;
                                           $$ = $1;
                                         } else {
                                           size_arrays->node[$1.index].must++;
                                         }
                                       }
  |  deviate_delete_opt_stmt unique_stmt { if (read_all) {
                                             if (yang_check_deviate_unique(trg, $1.deviation, s)) {
                                               YYABORT;
                                             }
                                             s = NULL;
                                             $$ = $1;
                                           } else {
                                             size_arrays->node[$1.index].unique++;
                                           }
                                         }
  |  deviate_delete_opt_stmt default_stmt { if (read_all) {
                                              if (yang_read_deviate_default(trg->ctx, $1.deviation, s)) {
                                                YYABORT;
                                              }
                                              s = NULL;
                                              $$ = $1;
                                            }
                                          }

deviate_replace_stmt: REPLACE_KEYWORD optsep { if (read_all && yang_read_deviate(actual, LY_DEVIATE_RPL)) {
                                                 YYABORT;
                                               }
                                             }
                      deviate_replace_end

deviate_replace_end: ';'
  |  '{' stmtsep
         deviate_replace_opt_stmt
     '}' ;

deviate_replace_opt_stmt: %empty { if (read_all) {
                                    $$.deviation = actual;
                                    actual_type = REPLACE_KEYWORD;
                                  }
                                }
  |  deviate_replace_opt_stmt type_stmt stmtsep { if (read_all) {
                                            if (unres_schema_add_node(trg, unres, $1.deviation->deviate->type, UNRES_TYPE_DER, $1.deviation->target)) {
                                              YYABORT;
                                            }
                                          }
                                        }
  |  deviate_replace_opt_stmt units_stmt { if (read_all) {
                                             if (yang_read_deviate_units(trg->ctx, $1.deviation, s)) {
                                               YYABORT;
                                             }
                                             s = NULL;
                                             $$ = $1;
                                           }
                                         }
  |  deviate_replace_opt_stmt default_stmt { if (read_all) {
                                               if (yang_read_deviate_default(trg->ctx, $1.deviation, s)) {
                                                 YYABORT;
                                               }
                                               s = NULL;
                                               $$ = $1;
                                             }
                                           }
  |  deviate_replace_opt_stmt config_stmt { if (read_all) {
                                              if (yang_read_deviate_config($1.deviation, $2)) {
                                                YYABORT;
                                              }
                                              $$ = $1;
                                            }
                                          }
  |  deviate_replace_opt_stmt mandatory_stmt { if (read_all) {
                                                 if (yang_read_deviate_mandatory($1.deviation, $2)) {
                                                   YYABORT;
                                                 }
                                                 $$ = $1;
                                               }
                                             }
  |  deviate_replace_opt_stmt min_elements_stmt { if (read_all) {
                                                    if ($1.deviation->deviate->min_set) {
                                                      LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "min-elements", "deviate");
                                                      YYABORT;
                                                    }
                                                    if (yang_read_deviate_minmax($1.deviation, $2, 0)) {
                                                      YYABORT;
                                                    }
                                                    $$ =  $1;
                                                  }
                                                }
  |  deviate_replace_opt_stmt max_elements_stmt { if (read_all) {
                                                    if ($1.deviation->deviate->max_set) {
                                                      LOGVAL(LYE_TOOMANY, LY_VLOG_NONE, NULL, "max-elements", "deviate");
                                                      YYABORT;
                                                    }
                                                    if (yang_read_deviate_minmax($1.deviation, $2, 1)) {
                                                      YYABORT;
                                                    }
                                                    $$ =  $1;
                                                  }
                                                }

when_stmt: WHEN_KEYWORD sep string  { if (read_all && !(actual=yang_read_when(trg, actual, actual_type, s))) {YYABORT;} s=NULL; actual_type=WHEN_KEYWORD;}
           when_end;

when_end: ';'
  |  '{' stmtsep
         when_opt_stmt
     '}'

when_opt_stmt: %empty
  |  when_opt_stmt description_stmt { if (read_all && yang_read_description(trg, actual, s, "when")) {
                                        YYABORT;
                                      }
                                      s = NULL;
                                    }
  |  when_opt_stmt reference_stmt { if (read_all && yang_read_reference(trg, actual, s, "when")) {
                                      YYABORT;
                                    }
                                    s = NULL;
                                  }

config_stmt: CONFIG_KEYWORD sep config_arg_str stmtend { $$ = $3; }

config_read_stmt: CONFIG_KEYWORD sep { read_all = (read_all) ? LY_READ_ONLY_SIZE : LY_READ_ALL; }
                  config_arg_str { read_all = (read_all) ? LY_READ_ONLY_SIZE : LY_READ_ALL; }
                  stmtend { $$ = $4; }

config_arg_str: TRUE_KEYWORD optsep { $$ = LYS_CONFIG_W | LYS_CONFIG_SET; }
  |  FALSE_KEYWORD optsep { $$ = LYS_CONFIG_R | LYS_CONFIG_SET; }
  |  string_1 { if (read_all) {
                  if (!strcmp(s, "true")) {
                    $$ = LYS_CONFIG_W | LYS_CONFIG_SET;
                  } else if (!strcmp(s, "false")) {
                    $$ = LYS_CONFIG_R | LYS_CONFIG_SET;
                  } else {
                    LOGVAL(LYE_INARG, LY_VLOG_NONE, NULL, s, "config");
                    free(s);
                    YYABORT;
                  }
                  free(s);
                  s = NULL;
                }
              }

mandatory_stmt: MANDATORY_KEYWORD sep mandatory_arg_str stmtend { $$ = $3; }

mandatory_read_stmt: MANDATORY_KEYWORD sep { read_all = (read_all) ? LY_READ_ONLY_SIZE : LY_READ_ALL; }
                     mandatory_arg_str { read_all = (read_all) ? LY_READ_ONLY_SIZE : LY_READ_ALL; }
                     stmtend { $$ = $4; }

mandatory_arg_str: TRUE_KEYWORD optsep { $$ = LYS_MAND_TRUE; }
  |  FALSE_KEYWORD optsep { $$ = LYS_MAND_FALSE; }
  |  string_1 { if (read_all) {
                  if (!strcmp(s, "true")) {
                    $$ = LYS_MAND_TRUE;
                  } else if (!strcmp(s, "false")) {
                    $$ = LYS_MAND_FALSE;
                  } else {
                    LOGVAL(LYE_INARG, LY_VLOG_NONE, NULL, s, "mandatory");
                    free(s);
                    YYABORT;
                  }
                  free(s);
                  s = NULL;
                }
              }

presence_stmt: PRESENCE_KEYWORD sep string stmtend;

min_elements_stmt: MIN_ELEMENTS_KEYWORD sep min_value_arg_str stmtend { $$ = $3; }

min_value_arg_str: non_negative_integer_value optsep { $$ = $1; }
  |  string_1 { if (read_all) {
                  if (strlen(s) == 1 && s[0] == '0') {
                    $$ = 0;
                  } else {
                    /* convert it to uint32_t */
                    uint64_t val;
                    char *endptr;

                    val = strtoul(s, &endptr, 10);
                    if (val > UINT32_MAX || *endptr) {
                        LOGVAL(LYE_INARG, LY_VLOG_NONE, NULL, s, "min-elements");
                        free(s);
                        YYABORT;
                    }
                    $$ = (uint32_t) val;
                  }
                  free(s);
                  s = NULL;
                }
              }

max_elements_stmt: MAX_ELEMENTS_KEYWORD sep max_value_arg_str stmtend { $$ = $3; }

max_value_arg_str: UNBOUNDED_KEYWORD optsep { $$ = 0; }
  |  positive_integer_value optsep { $$ = $1; }
  |  string_1 { if (read_all) {
                  if (!strcmp(s, "unbounded")) {
                    $$ = 0;
                  } else {
                    /* convert it to uint32_t */
                    uint64_t val;
                    char *endptr;

                    val = strtoul(s, &endptr, 10);
                    if (val > UINT32_MAX || *endptr) {
                        LOGVAL(LYE_INARG, LY_VLOG_NONE, NULL, s, "max-elements");
                        free(s);
                        YYABORT;
                    }
                    $$ = (uint32_t) val;
                  }
                  free(s);
                  s = NULL;
                }
              }

ordered_by_stmt: ORDERED_BY_KEYWORD sep ordered_by_arg_str stmtend { $$ = $3; }

ordered_by_arg_str: USER_KEYWORD optsep { $$ = LYS_USERORDERED; }
  |  SYSTEM_KEYWORD optsep { $$ = LYS_SYSTEMORDERED; }
  |  string_1 { if (!strcmp(s, "user")) {
                  $$ = LYS_USERORDERED;
                } else if (!strcmp(s, "system")) {
                  $$ = LYS_SYSTEMORDERED;
                } else {
                  free(s);
                  YYABORT;
                }
                free(s);
                s=NULL;
              }

must_stmt: MUST_KEYWORD sep string { if (read_all) {
                                       if (!(actual=yang_read_must(trg, actual, s, actual_type))) {YYABORT;}
                                       s=NULL;
                                       actual_type=MUST_KEYWORD;
                                     }
                                   }
           must_end;

must_end: ';'
  |  '{' stmtsep
         message_opt_stmt
     '}'
  ;

unique_stmt: UNIQUE_KEYWORD sep unique_arg_str;

unique_arg_str: descendant_schema_nodeid unique_arg
  |  string_1 stmtend;

unique_arg: sep descendant_schema_nodeid unique_arg
  |  stmtend;

key_stmt: KEY_KEYWORD sep key_arg_str;

key_arg_str: node_identifier { if (read_all){
                                 s = strdup(yyget_text(scanner));
                                 if (!s) {
                                   LOGMEM;
                                   YYABORT;
                                 }
                               }
                             }
             key_opt
  |  string_1 stmtend
  ;

key_opt: sep node_identifier { if (read_all) {
                                 s = ly_realloc(s,strlen(s) + yyget_leng(scanner) + 2);
                                 if (!s) {
                                   LOGMEM;
                                   YYABORT;
                                 }
                                 strcat(s," ");
                                 strcat(s, yyget_text(scanner));
                                }
                             }
         key_opt
  | stmtend
  ;

range_arg_str: string { if (read_all) {
                          $$ = actual;
                          if (!(actual = yang_read_range(trg, actual, s))) {
                             YYABORT;
                          }
                          actual_type = RANGE_KEYWORD;
                          s = NULL;
                        }
                      }

absolute_schema_nodeid: '/' node_identifier { if (read_all) {
                                                if (s) {
                                                  s = ly_realloc(s,strlen(s) + yyget_leng(scanner) + 2);
                                                  if (!s) {
                                                    LOGMEM;
                                                    YYABORT;
                                                  }
                                                  strcat(s,"/");
                                                  strcat(s, yyget_text(scanner));
                                                } else {
                                                  s = malloc(yyget_leng(scanner) + 2);
                                                  if (!s) {
                                                    LOGMEM;
                                                    YYABORT;
                                                  }
                                                  s[0]='/';
                                                  memcpy(s + 1, yyget_text(scanner), yyget_leng(scanner) + 1);
                                                }
                                              }
                                            }

absolute_schema_nodeids: absolute_schema_nodeid absolute_schema_nodeid_opt;

absolute_schema_nodeid_opt: %empty
  |  absolute_schema_nodeid_opt absolute_schema_nodeid
  ;

descendant_schema_nodeid: node_identifier { if (read_all)  {
                                              if (s) {
                                                s = ly_realloc(s,strlen(s) + yyget_leng(scanner) + 1);
                                                if (!s) {
                                                  LOGMEM;
                                                  YYABORT;
                                                }
                                                strcat(s, yyget_text(scanner));
                                              } else {
                                                s = strdup(yyget_text(scanner));
                                                if (!s) {
                                                  LOGMEM;
                                                  YYABORT;
                                                }
                                              }
                                            }
                                          }
                          absolute_schema_nodeid_opt;

path_arg_str: { tmp_s = yyget_text(scanner); } absolute_paths { if (read_all) {
                                                     s = strdup(tmp_s);
                                                     if (!s) {
                                                       LOGMEM;
                                                       YYABORT;
                                                     }
                                                     s[strlen(s) - 1] = '\0';
                                                   }
                                                 }
  |  { tmp_s = yyget_text(scanner); } relative_path { if (read_all) {
                                           s = strdup(tmp_s);
                                           if (!s) {
                                             LOGMEM;
                                             YYABORT;
                                           }
                                           s[strlen(s) - 1] = '\0';
                                         }
                                       }
  |  string_1
  ;

absolute_path: '/' node_identifier path_predicate

absolute_paths: absolute_path absolute_path_opt

absolute_path_opt: %empty
  |  absolute_path_opt absolute_path;

relative_path: relative_path_part1 relative_path_part1_opt descendant_path

relative_path_part1: DOUBLEDOT '/';

relative_path_part1_opt: %empty
  |  relative_path_part1_opt relative_path_part1;

descendant_path: node_identifier descendant_path_opt

descendant_path_opt: %empty
  |  path_predicate absolute_paths;

path_predicate: %empty
  | path_predicate '[' whitespace_opt path_equality_expr whitespace_opt ']'

path_equality_expr: node_identifier whitespace_opt '=' whitespace_opt path_key_expr

path_key_expr: current_function_invocation whitespace_opt '/' whitespace_opt
                     rel_path_keyexpr

rel_path_keyexpr: rel_path_keyexpr_part1 rel_path_keyexpr_part1_opt
                    node_identifier rel_path_keyexpr_part2
                     node_identifier

rel_path_keyexpr_part1: DOUBLEDOT whitespace_opt '/' whitespace_opt;

rel_path_keyexpr_part1_opt: %empty
  |  rel_path_keyexpr_part1_opt rel_path_keyexpr_part1;

rel_path_keyexpr_part2: %empty
  | rel_path_keyexpr_part2 whitespace_opt '/' whitespace_opt node_identifier;

current_function_invocation: CURRENT_KEYWORD whitespace_opt '(' whitespace_opt ')'

positive_integer_value: NON_NEGATIVE_INTEGER { /* convert it to uint32_t */
                                                unsigned long val;

                                                val = strtoul(yyget_text(scanner), NULL, 10);
                                                if (val > UINT32_MAX) {
                                                    LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "Converted number is very long.");
                                                    YYABORT;
                                                }
                                                $$ = (uint32_t) val;
                                             }

non_negative_integer_value: ZERO { $$ = 0; }
  |  positive_integer_value { $$ = $1; }
  ;

integer_value: ZERO { $$ = 0; }
  |  integer_value_convert { /* convert it to int32_t */
               int64_t val;

               val = strtoll(yyget_text(scanner), NULL, 10);
               if (val < INT32_MIN || val > INT32_MAX) {
                   LOGVAL(LYE_SPEC, LY_VLOG_NONE, NULL, "The number is not in the correct range (INT32_MIN..INT32_MAX): \"%d\"",val);
                   YYABORT;
               }
               $$ = (int32_t) val;
             }
  ;

integer_value_convert: INTEGER
  |  NON_NEGATIVE_INTEGER

prefix_arg_str: string_1
  |  identifiers optsep;

identifier_arg_str: identifiers optsep
  |  string_1 { if (read_all && lyp_check_identifier(s, LY_IDENT_SIMPLE, trg, NULL)) {
                    free(s);
                    YYABORT;
                }
              }

node_identifier: identifier
  |  IDENTIFIERPREFIX
  ;

identifier_ref_arg_str: identifiers optsep
  | identifiers_ref optsep
  | string_1 { if (read_all) {
                 char *tmp;

                 if ((tmp = strchr(s, ':'))) {
                   *tmp = '\0';
                   /* check prefix */
                   if (lyp_check_identifier(s, LY_IDENT_SIMPLE, trg, NULL)) {
                     free(s);
                     YYABORT;
                   }
                   /* check identifier */
                   if (lyp_check_identifier(tmp + 1, LY_IDENT_SIMPLE, trg, NULL)) {
                     free(s);
                     YYABORT;
                   }
                   *tmp = ':';
                 } else {
                   /* check identifier */
                   if (lyp_check_identifier(s, LY_IDENT_SIMPLE, trg, NULL)) {
                     free(s);
                     YYABORT;
                   }
                 }
               }
             }

stmtend: ';' stmtsep
  | '{' stmtsep '}' stmtsep
  ;

stmtsep: %empty
  | stmtsep sep_stmt
  | stmtsep unknown_statement
  ;

unknown_statement: IDENTIFIERPREFIX { if (read_all ) {
                                       if (yang_use_extension(trg, data_node, actual, yyget_text(scanner))) {
                                         YYABORT;
                                       }
                                     }
                                   }
                   string_opt unknown_statement_end

string_opt: string_opt_part1 string_opt_part2

string_opt_part1: %empty
  |  sep

string_opt_part2: %empty
  |  STRING optsep string_opt_part3

string_opt_part3: %empty
  |  string_opt_part3 '+' optsep STRING optsep

unknown_statement_end: ';'
  |  '{' optsep unknown_statement2_opt '}'

unknown_statement2_opt: %empty
  |  node_identifier string_opt unknown_statement2_end;

unknown_statement2_end: ';' optsep
  |  '{' optsep unknown_statement2_opt '}' optsep

sep_stmt: WHITESPACE
  | EOL
  ;

optsep: %empty
  | optsep sep_stmt
  ;

sep: sep_stmt optsep;

whitespace_opt: %empty
  | WHITESPACE
  ;


string: strings { if (read_all){
                    s = strdup(yyget_text(scanner));
                    if (!s) {
                      LOGMEM;
                      YYABORT;
                    }
                  }
                }
        optsep
  |  string_1

strings: STRINGS
  |  REVISION_DATE
  |  identifier
  |  IDENTIFIERPREFIX
  |  ZERO
  |  INTEGER
  |  NON_NEGATIVE_INTEGER

identifier: IDENTIFIER
  |  ANYXML_KEYWORD
  |  ARGUMENT_KEYWORD
  |  AUGMENT_KEYWORD
  |  BASE_KEYWORD
  |  BELONGS_TO_KEYWORD
  |  BIT_KEYWORD
  |  CASE_KEYWORD
  |  CHOICE_KEYWORD
  |  CONFIG_KEYWORD
  |  CONTACT_KEYWORD
  |  CONTAINER_KEYWORD
  |  DEFAULT_KEYWORD
  |  DESCRIPTION_KEYWORD
  |  ENUM_KEYWORD
  |  ERROR_APP_TAG_KEYWORD
  |  ERROR_MESSAGE_KEYWORD
  |  EXTENSION_KEYWORD
  |  DEVIATION_KEYWORD
  |  DEVIATE_KEYWORD
  |  FEATURE_KEYWORD
  |  FRACTION_DIGITS_KEYWORD
  |  GROUPING_KEYWORD
  |  IDENTITY_KEYWORD
  |  IF_FEATURE_KEYWORD
  |  IMPORT_KEYWORD
  |  INCLUDE_KEYWORD
  |  INPUT_KEYWORD
  |  KEY_KEYWORD
  |  LEAF_KEYWORD
  |  LEAF_LIST_KEYWORD
  |  LENGTH_KEYWORD
  |  LIST_KEYWORD
  |  MANDATORY_KEYWORD
  |  MAX_ELEMENTS_KEYWORD
  |  MIN_ELEMENTS_KEYWORD
  |  MODULE_KEYWORD
  |  MUST_KEYWORD
  |  NAMESPACE_KEYWORD
  |  NOTIFICATION_KEYWORD
  |  ORDERED_BY_KEYWORD
  |  ORGANIZATION_KEYWORD
  |  OUTPUT_KEYWORD
  |  PATH_KEYWORD
  |  PATTERN_KEYWORD
  |  POSITION_KEYWORD
  |  PREFIX_KEYWORD
  |  PRESENCE_KEYWORD
  |  RANGE_KEYWORD
  |  REFERENCE_KEYWORD
  |  REFINE_KEYWORD
  |  REQUIRE_INSTANCE_KEYWORD
  |  REVISION_KEYWORD
  |  REVISION_DATE_KEYWORD
  |  RPC_KEYWORD
  |  STATUS_KEYWORD
  |  SUBMODULE_KEYWORD
  |  TYPE_KEYWORD
  |  TYPEDEF_KEYWORD
  |  UNIQUE_KEYWORD
  |  UNITS_KEYWORD
  |  USES_KEYWORD
  |  VALUE_KEYWORD
  |  WHEN_KEYWORD
  |  YANG_VERSION_KEYWORD
  |  YIN_ELEMENT_KEYWORD
  |  ADD_KEYWORD
  |  CURRENT_KEYWORD
  |  DELETE_KEYWORD
  |  DEPRECATED_KEYWORD
  |  FALSE_KEYWORD
  |  NOT_SUPPORTED_KEYWORD
  |  OBSOLETE_KEYWORD
  |  REPLACE_KEYWORD
  |  SYSTEM_KEYWORD
  |  TRUE_KEYWORD
  |  UNBOUNDED_KEYWORD
  |  USER_KEYWORD
  ;

identifiers: identifier { if (read_all) {
                            s = strdup(yyget_text(scanner));
                            if (!s) {
                              LOGMEM;
                              YYABORT;
                            }
                          }
                        }

identifiers_ref: IDENTIFIERPREFIX { if (read_all) {
                                      s = strdup(yyget_text(scanner));
                                      if (!s) {
                                        LOGMEM;
                                        YYABORT;
                                      }
                                    }
                                  }

%%

void yyerror(YYLTYPE *yylloc, void *scanner, ...){

  (void)yylloc; /* unused */
  LOGVAL(LYE_INSTMT, LY_VLOG_NONE, NULL, yyget_text(scanner));
}