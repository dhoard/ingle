// src/runner_main.c — the standalone, FRONTEND-FREE bytecode runner (OFI-224 Stage B2).
//
// Loads a serialized `.igb` container (docs/design/bytecode-container.md) and executes it on the VM — the
// exact run_bytecode path from src/main.c, but as its OWN small binary with NO lexer / parser / checker /
// codegen / cgen_c linked in. This is what the self-hosted `inglec --emit=run` hands its compiled bytecode
// to, so quick-run stands entirely on the KEPT execution layer (the VM + the C runtime, both C by design —
// like Go's runtime) and does not depend on the frozen C frontend, which retires in v1.1 (G6).
//
// Built from the VM + runtime translation units only (see the `runner` target in the Makefile). The two
// functions below are copied verbatim from src/main.c (report_unhandled_error / run_bytecode) so this file
// stays self-contained and the frontend's main.c is not linked. Usage: inglec-run <file.igb>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "program.h"
#include "bytecode_io.h"
#include "vm.h"
#include "value.h"
#include "fault.h"


// report_unhandled_error — verbatim from src/main.c. Detects an Err/None that `main` returned without
// handling and reports it as a Fault (FCAT_UNHANDLED_ERR). Returns 1 (and renders) if it was an unhandled
// Err/None, else 0. Must run before vm_destroy frees the value.
static int report_unhandled_error(const char *path, const CompiledProgram *prog,
                                  const VM *vm, Value result) {
    if (!IS_STRUCT(result) || !AS_STRUCT(result)->is_enum) {
        return 0;
    }
    ObjStruct *e = AS_STRUCT(result);
    int is_err  = prog->result_enum_id >= 0 &&
                  e->type_id == prog->result_enum_id && e->tag == prog->err_tag;
    int is_none = prog->option_enum_id >= 0 &&
                  e->type_id == prog->option_enum_id && e->tag == prog->none_tag;
    if (!is_err && !is_none) {
        return 0;
    }
    Fault f;
    memset(&f, 0, sizeof f);
    f.severity = FSEV_ERROR;
    f.category = FCAT_UNHANDLED_ERR;
    f.file     = path;
    f.fn       = "main";
    if (is_err) {
        f.code    = "unhandled_error";
        f.message = "an Err returned by main was never handled";
        f.why     = "a Result that reaches main must be handled (match its Err), not left to propagate out";
        f.hint    = "match the Result and handle the Err arm (or have main do something with the error)";
        if (e->field_count >= 1) {
            Value payload;
            memcpy(&payload, e->data, sizeof(Value));   // an enum field is a 16-byte boxed Value
            f.values[0].name = "error";
            render_value_into(f.values[0].rendered, sizeof f.values[0].rendered, payload, prog);
            f.value_count = 1;
        }
    } else {
        f.code    = "unhandled_none";
        f.message = "a None returned by main was never handled";
        f.why     = "an Option that reaches main must be handled (match its None), not left to propagate out";
        f.hint    = "match the Option and handle the None arm";
    }
    vm_route(vm, f.route, &f.route_count);
    fault_render(&f, stderr);
    return 1;
}


// run_bytecode — verbatim from src/main.c. Deserialize the `.igb` and run it on the VM, with the same
// exit-code and unhandled-Err/None handling emit_run uses, but with NO front end. Returns 0 / 65 / 66.
static int run_bytecode(const char *path) {
    CompiledProgram prog;
    compiled_program_init(&prog);
    if (bytecode_read(path, &prog) != 0) {
        fprintf(stderr, "inglec: could not load bytecode '%s' (unreadable, malformed, or a VM-ABI mismatch)\n",
                path);
        compiled_program_free(&prog);
        return 66;
    }
    VM   *vm     = vm_create(&prog);
    Value result = INT_VAL(0);
    int   rc     = 0;
    if (vm_run(vm, &result, NULL) == VM_OK) {
        int code;
        if (vm_exited(vm, &code)) {
            vm_destroy(vm);
            compiled_program_free(&prog);
            fflush(stdout);
            exit(code);
        }
        if (report_unhandled_error(path, &prog, vm, result)) {
            rc = 65;   // an unhandled Err/None reached main → Fault on stderr, non-zero exit
        } else if (IS_INT(result)) {
            printf("=> %lld\n", (long long)AS_INT(result));
        } else if (IS_FLOAT(result)) {
            printf("=> %g\n", AS_FLOAT(result));
        } else if (IS_STRING(result)) {
            printf("=> %s\n", AS_CSTRING(result));
        } else {
            printf("=> <obj>\n");
        }
    } else {
        rc = 65;
    }
    vm_destroy(vm);
    compiled_program_free(&prog);
    return rc;
}


int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: inglec-run <file.igb>\n");
        return 2;
    }
    return run_bytecode(argv[1]);
}
