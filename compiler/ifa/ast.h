/* -*-Mode: c++;-*-
*/
#ifndef _ast_H_
#define _ast_H_

#include <stdio.h>
#include "defs.h"
#include "ifa.h"

class Fun;
class PNode;
class Sym;
class IF1;
class Var;

class ASTCopyContext : public gc {
 public:
  Map<Fun *, Fun *> *fmap;
  Map<PNode *, PNode *> *nmap;
  Map<Var *, Var *> *vmap;
  Map<Sym *, Sym *> smap;
  ASTCopyContext() : fmap(0), nmap(0), vmap(0) {}
};

void build_module(Sym *sym, Sym *init);
void init_ast(IFACallbacks *callbacks);
void finalize_types(IF1 *, int import_included_ivars = true);
void make_meta_type(Sym *s);
void build_type_hierarchy(int compute_structural_value_hierarchy = 0);
void compute_type_size(Sym *s);

#endif
