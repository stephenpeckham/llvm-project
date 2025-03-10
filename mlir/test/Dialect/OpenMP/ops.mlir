// RUN: mlir-opt %s | mlir-opt | FileCheck %s

func.func @omp_barrier() -> () {
  // CHECK: omp.barrier
  omp.barrier
  return
}

func.func @omp_master() -> () {
  // CHECK: omp.master
  omp.master {
    // CHECK: omp.terminator
    omp.terminator
  }

  return
}

func.func @omp_taskwait() -> () {
  // CHECK: omp.taskwait
  omp.taskwait
  return
}

func.func @omp_taskyield() -> () {
  // CHECK: omp.taskyield
  omp.taskyield
  return
}

// CHECK-LABEL: func @omp_flush
// CHECK-SAME: ([[ARG0:%.*]]: memref<i32>) {
func.func @omp_flush(%arg0 : memref<i32>) -> () {
  // Test without data var
  // CHECK: omp.flush
  omp.flush

  // Test with one data var
  // CHECK: omp.flush([[ARG0]] : memref<i32>)
  omp.flush(%arg0 : memref<i32>)

  // Test with two data var
  // CHECK: omp.flush([[ARG0]], [[ARG0]] : memref<i32>, memref<i32>)
  omp.flush(%arg0, %arg0: memref<i32>, memref<i32>)

  return
}

func.func @omp_terminator() -> () {
  // CHECK: omp.terminator
  omp.terminator
}

func.func @omp_parallel(%data_var : memref<i32>, %if_cond : i1, %num_threads : i32) -> () {
  // CHECK: omp.parallel if(%{{.*}}) num_threads(%{{.*}} : i32) allocate(%{{.*}} : memref<i32> -> %{{.*}} : memref<i32>)
  "omp.parallel" (%if_cond, %num_threads, %data_var, %data_var) ({

  // test without if condition
  // CHECK: omp.parallel num_threads(%{{.*}} : i32) allocate(%{{.*}} : memref<i32> -> %{{.*}} : memref<i32>)
    "omp.parallel"(%num_threads, %data_var, %data_var) ({
      omp.terminator
    }) {operandSegmentSizes = array<i32: 0,1,1,1,0>} : (i32, memref<i32>, memref<i32>) -> ()

  // CHECK: omp.barrier
    omp.barrier

  // test without num_threads
  // CHECK: omp.parallel if(%{{.*}}) allocate(%{{.*}} : memref<i32> -> %{{.*}} : memref<i32>)
    "omp.parallel"(%if_cond, %data_var, %data_var) ({
      omp.terminator
    }) {operandSegmentSizes = array<i32: 1,0,1,1,0>} : (i1, memref<i32>, memref<i32>) -> ()

  // test without allocate
  // CHECK: omp.parallel if(%{{.*}}) num_threads(%{{.*}} : i32)
    "omp.parallel"(%if_cond, %num_threads) ({
      omp.terminator
    }) {operandSegmentSizes = array<i32: 1,1,0,0,0>} : (i1, i32) -> ()

    omp.terminator
  }) {operandSegmentSizes = array<i32: 1,1,1,1,0>, proc_bind_val = #omp<procbindkind spread>} : (i1, i32, memref<i32>, memref<i32>) -> ()

  // test with multiple parameters for single variadic argument
  // CHECK: omp.parallel allocate(%{{.*}} : memref<i32> -> %{{.*}} : memref<i32>)
  "omp.parallel" (%data_var, %data_var) ({
    omp.terminator
  }) {operandSegmentSizes = array<i32: 0,0,1,1,0>} : (memref<i32>, memref<i32>) -> ()

  return
}

func.func @omp_parallel_pretty(%data_var : memref<i32>, %if_cond : i1, %num_threads : i32, %allocator : si32) -> () {
 // CHECK: omp.parallel
 omp.parallel {
  omp.terminator
 }

 // CHECK: omp.parallel num_threads(%{{.*}} : i32)
 omp.parallel num_threads(%num_threads : i32) {
   omp.terminator
 }

 %n_index = arith.constant 2 : index
 // CHECK: omp.parallel num_threads(%{{.*}} : index)
 omp.parallel num_threads(%n_index : index) {
   omp.terminator
 }

 %n_i64 = arith.constant 4 : i64
 // CHECK: omp.parallel num_threads(%{{.*}} : i64)
 omp.parallel num_threads(%n_i64 : i64) {
   omp.terminator
 }

 // CHECK: omp.parallel allocate(%{{.*}} : memref<i32> -> %{{.*}} : memref<i32>)
 omp.parallel allocate(%data_var : memref<i32> -> %data_var : memref<i32>) {
   omp.terminator
 }

 // CHECK: omp.parallel
 // CHECK-NEXT: omp.parallel if(%{{.*}} : i1)
 omp.parallel {
   omp.parallel if(%if_cond: i1) {
     omp.terminator
   }
   omp.terminator
 }

 // CHECK omp.parallel if(%{{.*}}) num_threads(%{{.*}} : i32) private(%{{.*}} : memref<i32>) proc_bind(close)
 omp.parallel num_threads(%num_threads : i32) if(%if_cond: i1) proc_bind(close) {
   omp.terminator
 }

  return
}

// CHECK-LABEL: omp_wsloop
func.func @omp_wsloop(%lb : index, %ub : index, %step : index, %data_var : memref<i32>, %linear_var : i32, %chunk_var : i32) -> () {

  // CHECK: omp.wsloop ordered(1)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  "omp.wsloop" (%lb, %ub, %step) ({
    ^bb0(%iv: index):
      omp.yield
  }) {operandSegmentSizes = array<i32: 1,1,1,0,0,0,0>, ordered_val = 1} :
    (index, index, index) -> ()

  // CHECK: omp.wsloop linear(%{{.*}} = %{{.*}} : memref<i32>) schedule(static)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  "omp.wsloop" (%lb, %ub, %step, %data_var, %linear_var) ({
    ^bb0(%iv: index):
      omp.yield
  }) {operandSegmentSizes = array<i32: 1,1,1,1,1,0,0>, schedule_val = #omp<schedulekind static>} :
    (index, index, index, memref<i32>, i32) -> ()

  // CHECK: omp.wsloop linear(%{{.*}} = %{{.*}} : memref<i32>, %{{.*}} = %{{.*}} : memref<i32>) schedule(static)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  "omp.wsloop" (%lb, %ub, %step, %data_var, %data_var, %linear_var, %linear_var) ({
    ^bb0(%iv: index):
      omp.yield
  }) {operandSegmentSizes = array<i32: 1,1,1,2,2,0,0>, schedule_val = #omp<schedulekind static>} :
    (index, index, index, memref<i32>, memref<i32>, i32, i32) -> ()

  // CHECK: omp.wsloop linear(%{{.*}} = %{{.*}} : memref<i32>) schedule(dynamic = %{{.*}}) ordered(2)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  "omp.wsloop" (%lb, %ub, %step, %data_var, %linear_var, %chunk_var) ({
    ^bb0(%iv: index):
      omp.yield
  }) {operandSegmentSizes = array<i32: 1,1,1,1,1,0,1>, schedule_val = #omp<schedulekind dynamic>, ordered_val = 2} :
    (index, index, index, memref<i32>, i32, i32) -> ()

  // CHECK: omp.wsloop schedule(auto) nowait
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  "omp.wsloop" (%lb, %ub, %step) ({
    ^bb0(%iv: index):
      omp.yield
  }) {operandSegmentSizes = array<i32: 1,1,1,0,0,0,0>, nowait, schedule_val = #omp<schedulekind auto>} :
    (index, index, index) -> ()

  return
}

// CHECK-LABEL: omp_wsloop_pretty
func.func @omp_wsloop_pretty(%lb : index, %ub : index, %step : index, %data_var : memref<i32>, %linear_var : i32, %chunk_var : i32, %chunk_var2 : i16) -> () {

  // CHECK: omp.wsloop ordered(2)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop ordered(2)
  for (%iv) : index = (%lb) to (%ub) step (%step) {
    omp.yield
  }

  // CHECK: omp.wsloop linear(%{{.*}} = %{{.*}} : memref<i32>) schedule(static)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop schedule(static) linear(%data_var = %linear_var : memref<i32>)
  for (%iv) : index = (%lb) to (%ub) step (%step) {
    omp.yield
  }

  // CHECK: omp.wsloop linear(%{{.*}} = %{{.*}} : memref<i32>) schedule(static = %{{.*}} : i32) ordered(2)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop ordered(2) linear(%data_var = %linear_var : memref<i32>) schedule(static = %chunk_var : i32)
  for (%iv) : index = (%lb) to (%ub) step (%step) {
    omp.yield
  }

  // CHECK: omp.wsloop linear(%{{.*}} = %{{.*}} : memref<i32>) schedule(dynamic = %{{.*}} : i32, nonmonotonic) ordered(2)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop ordered(2) linear(%data_var = %linear_var : memref<i32>) schedule(dynamic = %chunk_var : i32, nonmonotonic)
  for (%iv) : index = (%lb) to (%ub) step (%step)  {
    omp.yield
  }

  // CHECK: omp.wsloop linear(%{{.*}} = %{{.*}} : memref<i32>) schedule(dynamic = %{{.*}} : i16, monotonic) ordered(2)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop ordered(2) linear(%data_var = %linear_var : memref<i32>) schedule(dynamic = %chunk_var2 : i16, monotonic)
  for (%iv) : index = (%lb) to (%ub) step (%step) {
    omp.yield
  }

  // CHECK: omp.wsloop for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop for (%iv) : index = (%lb) to (%ub) step (%step) {
    omp.yield
  }

  // CHECK: omp.wsloop for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) inclusive step (%{{.*}})
  omp.wsloop for (%iv) : index = (%lb) to (%ub) inclusive step (%step) {
    omp.yield
  }

  // CHECK: omp.wsloop nowait
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop nowait
  for (%iv) : index = (%lb) to (%ub) step (%step) {
    omp.yield
  }

  // CHECK: omp.wsloop nowait order(concurrent)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop order(concurrent) nowait
  for (%iv) : index = (%lb) to (%ub) step (%step) {
    omp.yield
  }

  return
}

// CHECK-LABEL: omp_wsloop_pretty_multi_block
func.func @omp_wsloop_pretty_multi_block(%lb : index, %ub : index, %step : index, %data1 : memref<?xi32>, %data2 : memref<?xi32>) -> () {

  // CHECK: omp.wsloop for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop for (%iv) : index = (%lb) to (%ub) step (%step) {
    %1 = "test.payload"(%iv) : (index) -> (i32)
    cf.br ^bb1(%1: i32)
  ^bb1(%arg: i32):
    memref.store %arg, %data1[%iv] : memref<?xi32>
    omp.yield
  }

  // CHECK: omp.wsloop for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop for (%iv) : index = (%lb) to (%ub) step (%step) {
    %c = "test.condition"(%iv) : (index) -> (i1)
    %v1 = "test.payload"(%iv) : (index) -> (i32)
    cf.cond_br %c, ^bb1(%v1: i32), ^bb2(%v1: i32)
  ^bb1(%arg0: i32):
    memref.store %arg0, %data1[%iv] : memref<?xi32>
    cf.br ^bb3
  ^bb2(%arg1: i32):
    memref.store %arg1, %data2[%iv] : memref<?xi32>
    cf.br ^bb3
  ^bb3:
    omp.yield
  }

  // CHECK: omp.wsloop for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop for (%iv) : index = (%lb) to (%ub) step (%step) {
    %c = "test.condition"(%iv) : (index) -> (i1)
    %v1 = "test.payload"(%iv) : (index) -> (i32)
    cf.cond_br %c, ^bb1(%v1: i32), ^bb2(%v1: i32)
  ^bb1(%arg0: i32):
    memref.store %arg0, %data1[%iv] : memref<?xi32>
    omp.yield
  ^bb2(%arg1: i32):
    memref.store %arg1, %data2[%iv] : memref<?xi32>
    omp.yield
  }

  return
}

// CHECK-LABEL: omp_wsloop_pretty_non_index
func.func @omp_wsloop_pretty_non_index(%lb1 : i32, %ub1 : i32, %step1 : i32, %lb2 : i64, %ub2 : i64, %step2 : i64,
                           %data1 : memref<?xi32>, %data2 : memref<?xi64>) -> () {

  // CHECK: omp.wsloop for (%{{.*}}) : i32 = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop for (%iv1) : i32 = (%lb1) to (%ub1) step (%step1) {
    %1 = "test.payload"(%iv1) : (i32) -> (index)
    cf.br ^bb1(%1: index)
  ^bb1(%arg1: index):
    memref.store %iv1, %data1[%arg1] : memref<?xi32>
    omp.yield
  }

  // CHECK: omp.wsloop for (%{{.*}}) : i64 = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.wsloop for (%iv2) : i64 = (%lb2) to (%ub2) step (%step2) {
    %2 = "test.payload"(%iv2) : (i64) -> (index)
    cf.br ^bb1(%2: index)
  ^bb1(%arg2: index):
    memref.store %iv2, %data2[%arg2] : memref<?xi64>
    omp.yield
  }

  return
}

// CHECK-LABEL: omp_wsloop_pretty_multiple
func.func @omp_wsloop_pretty_multiple(%lb1 : i32, %ub1 : i32, %step1 : i32, %lb2 : i32, %ub2 : i32, %step2 : i32, %data1 : memref<?xi32>) -> () {

  // CHECK: omp.wsloop for (%{{.*}}, %{{.*}}) : i32 = (%{{.*}}, %{{.*}}) to (%{{.*}}, %{{.*}}) step (%{{.*}}, %{{.*}})
  omp.wsloop for (%iv1, %iv2) : i32 = (%lb1, %lb2) to (%ub1, %ub2) step (%step1, %step2) {
    %1 = "test.payload"(%iv1) : (i32) -> (index)
    %2 = "test.payload"(%iv2) : (i32) -> (index)
    memref.store %iv1, %data1[%1] : memref<?xi32>
    memref.store %iv2, %data1[%2] : memref<?xi32>
    omp.yield
  }

  return
}

// CHECK-LABEL: omp_simdloop
func.func @omp_simdloop(%lb : index, %ub : index, %step : index) -> () {
  // CHECK: omp.simdloop for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  "omp.simdloop" (%lb, %ub, %step) ({
    ^bb0(%iv: index):
      omp.yield
  }) {operandSegmentSizes = array<i32: 1,1,1,0,0,0>} :
    (index, index, index) -> ()

  return
}

// CHECK-LABEL: omp_simdloop_aligned_list
func.func @omp_simdloop_aligned_list(%arg0 : index, %arg1 : index, %arg2 : index,
                                     %arg3 : memref<i32>, %arg4 : memref<i32>) -> () {
  // CHECK:      omp.simdloop   aligned(%{{.*}} : memref<i32> -> 32 : i64,
  // CHECK-SAME: %{{.*}} : memref<i32> -> 128 : i64)
  // CHECK-SAME: for  (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}}) {
  "omp.simdloop"(%arg0, %arg1, %arg2, %arg3, %arg4) ({
    ^bb0(%arg5: index):
      "omp.yield"() : () -> ()
  }) {alignment_values = [32, 128],
      operandSegmentSizes = array<i32: 1, 1, 1, 2, 0, 0>} : (index, index, index, memref<i32>, memref<i32>) -> ()
  return
}

// CHECK-LABEL: omp_simdloop_aligned_single
func.func @omp_simdloop_aligned_single(%arg0 : index, %arg1 : index, %arg2 : index,
                                       %arg3 : memref<i32>, %arg4 : memref<i32>) -> () {
  // CHECK:      omp.simdloop   aligned(%{{.*}} : memref<i32> -> 32 : i64)
  // CHECK-SAME: for  (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}}) {
  "omp.simdloop"(%arg0, %arg1, %arg2, %arg3) ({
    ^bb0(%arg5: index):
      "omp.yield"() : () -> ()
  }) {alignment_values = [32],
      operandSegmentSizes = array<i32: 1, 1, 1, 1, 0, 0>} : (index, index, index, memref<i32>) -> ()
  return
}

// CHECK-LABEL: omp_simdloop_nontemporal_list
func.func @omp_simdloop_nontemporal_list(%arg0 : index,
                                         %arg1 : index,
                                         %arg2 : index,
                                         %arg3 : memref<i32>,
                                         %arg4 : memref<i64>) -> () {
  // CHECK:      omp.simdloop   nontemporal(%{{.*}}, %{{.*}} : memref<i32>, memref<i64>)
  // CHECK-SAME: for  (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}}) {
  "omp.simdloop"(%arg0, %arg1, %arg2, %arg3, %arg4) ({
    ^bb0(%arg5: index):
      "omp.yield"() : () -> ()
  }) {operandSegmentSizes = array<i32: 1, 1, 1, 0, 0, 2>} : (index, index, index, memref<i32>, memref<i64>) -> ()
  return
}

// CHECK-LABEL: omp_simdloop_nontemporal_single
func.func @omp_simdloop_nontemporal_single(%arg0 : index,
                                           %arg1 : index,
                                           %arg2 : index,
                                           %arg3 : memref<i32>,
                                           %arg4 : memref<i64>) -> () {
  // CHECK:      omp.simdloop   nontemporal(%{{.*}} : memref<i32>)
  // CHECK-SAME: for  (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}}) {
  "omp.simdloop"(%arg0, %arg1, %arg2, %arg3) ({
    ^bb0(%arg5: index):
      "omp.yield"() : () -> ()
  }) {operandSegmentSizes = array<i32: 1, 1, 1, 0, 0, 1>} : (index, index, index, memref<i32>) -> ()
  return
}

// CHECK-LABEL: omp_simdloop_pretty
func.func @omp_simdloop_pretty(%lb : index, %ub : index, %step : index) -> () {
  // CHECK: omp.simdloop for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.simdloop for (%iv) : index = (%lb) to (%ub) step (%step) {
    omp.yield
  }
  return
}

// CHECK-LABEL:   func.func @omp_simdloop_pretty_aligned(
func.func @omp_simdloop_pretty_aligned(%lb : index, %ub : index, %step : index,
                                       %data_var : memref<i32>,
                                       %data_var1 : memref<i32>) -> () {
  // CHECK:      omp.simdloop   aligned(%{{.*}} : memref<i32> -> 32 : i64,
  // CHECK-SAME: %{{.*}} : memref<i32> -> 128 : i64)
  // CHECK-SAME: for  (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}}) {
  omp.simdloop aligned(%data_var :  memref<i32> -> 32, %data_var1 : memref<i32> -> 128)
    for (%iv) : index = (%lb) to (%ub) step (%step) {
      omp.yield
  }
  return
}

// CHECK-LABEL: omp_simdloop_pretty_if
func.func @omp_simdloop_pretty_if(%lb : index, %ub : index, %step : index, %if_cond : i1) -> () {
  // CHECK: omp.simdloop if(%{{.*}}) for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.simdloop if(%if_cond) for (%iv): index = (%lb) to (%ub) step (%step) {
    omp.yield
  }
  return
}

// CHECK-LABEL:   func.func @omp_simdloop_pretty_nontemporal
func.func @omp_simdloop_pretty_nontemporal(%lb : index,
                                           %ub : index,
                                           %step : index,
                                           %data_var : memref<i32>,
                                           %data_var1 : memref<i32>) -> () {
  // CHECK:      omp.simdloop   nontemporal(%{{.*}}, %{{.*}} : memref<i32>, memref<i32>)
  // CHECK-SAME: for  (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}}) {
  omp.simdloop nontemporal(%data_var, %data_var1 : memref<i32>, memref<i32>)
    for (%iv) : index = (%lb) to (%ub) step (%step) {
      omp.yield
  }
  return
}
// CHECK-LABEL: omp_simdloop_pretty_order
func.func @omp_simdloop_pretty_order(%lb : index, %ub : index, %step : index) -> () {
  // CHECK: omp.simdloop order(concurrent)
  // CHECK-SAME: for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.simdloop order(concurrent) for (%iv): index = (%lb) to (%ub) step (%step) {
    omp.yield
  }
  return
}

// CHECK-LABEL: omp_simdloop_pretty_simdlen
func.func @omp_simdloop_pretty_simdlen(%lb : index, %ub : index, %step : index) -> () {
  // CHECK: omp.simdloop simdlen(2) for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.simdloop simdlen(2) for (%iv): index = (%lb) to (%ub) step (%step) {
    omp.yield
  }
  return
}

// CHECK-LABEL: omp_simdloop_pretty_safelen
func.func @omp_simdloop_pretty_safelen(%lb : index, %ub : index, %step : index) -> () {
  // CHECK: omp.simdloop safelen(2) for (%{{.*}}) : index = (%{{.*}}) to (%{{.*}}) step (%{{.*}})
  omp.simdloop safelen(2) for (%iv): index = (%lb) to (%ub) step (%step) {
    omp.yield
  }
  return
}

// CHECK-LABEL: omp_simdloop_pretty_multiple
func.func @omp_simdloop_pretty_multiple(%lb1 : index, %ub1 : index, %step1 : index, %lb2 : index, %ub2 : index, %step2 : index) -> () {
  // CHECK: omp.simdloop for (%{{.*}}, %{{.*}}) : index = (%{{.*}}, %{{.*}}) to (%{{.*}}, %{{.*}}) step (%{{.*}}, %{{.*}})
  omp.simdloop for (%iv1, %iv2) : index = (%lb1, %lb2) to (%ub1, %ub2) step (%step1, %step2) {
    omp.yield
  }
  return
}

// CHECK-LABEL: omp_distribute
func.func @omp_distribute(%chunk_size : i32, %data_var : memref<i32>) -> () {
  // CHECK: omp.distribute
  "omp.distribute" () ({
    omp.terminator
  }) {} : () -> ()
  // CHECK: omp.distribute
  omp.distribute {
    omp.terminator
  }
  // CHECK: omp.distribute dist_schedule_static
  omp.distribute dist_schedule_static {
    omp.terminator
  }
  // CHECK: omp.distribute dist_schedule_static chunk_size(%{{.+}} : i32)
  omp.distribute dist_schedule_static chunk_size(%chunk_size : i32) {
    omp.terminator
  }
  // CHECK: omp.distribute order(concurrent)
  omp.distribute order(concurrent) {
    omp.terminator
  }
  // CHECK: omp.distribute allocate(%{{.+}} : memref<i32> -> %{{.+}} : memref<i32>)
  omp.distribute allocate(%data_var : memref<i32> -> %data_var : memref<i32>) {
    omp.terminator
  }
return
}


// CHECK-LABEL: omp_target
func.func @omp_target(%if_cond : i1, %device : si32,  %num_threads : i32, %map1: memref<?xi32>, %map2: memref<?xi32>) -> () {

    // Test with optional operands; if_expr, device, thread_limit, private, firstprivate and nowait.
    // CHECK: omp.target if({{.*}}) device({{.*}}) thread_limit({{.*}}) nowait
    "omp.target"(%if_cond, %device, %num_threads) ({
       // CHECK: omp.terminator
       omp.terminator
    }) {nowait, operandSegmentSizes = array<i32: 1,1,1,0,0>} : ( i1, si32, i32 ) -> ()

    // Test with optional map clause.
    // CHECK: %[[MAP_A:.*]] = omp.map_info var_ptr(%[[VAL_1:.*]] : memref<?xi32>, tensor<?xi32>)   map_clauses(tofrom) capture(ByRef) -> memref<?xi32> {name = ""}
    // CHECK: %[[MAP_B:.*]] = omp.map_info var_ptr(%[[VAL_2:.*]] : memref<?xi32>, tensor<?xi32>)   map_clauses(exit_release_or_enter_alloc) capture(ByRef) -> memref<?xi32> {name = ""}
    // CHECK: omp.target map_entries(%[[MAP_A]] -> {{.*}}, %[[MAP_B]] -> {{.*}} : memref<?xi32>, memref<?xi32>) {
    %mapv1 = omp.map_info var_ptr(%map1 : memref<?xi32>, tensor<?xi32>)   map_clauses(tofrom) capture(ByRef) -> memref<?xi32> {name = ""}
    %mapv2 = omp.map_info var_ptr(%map2 : memref<?xi32>, tensor<?xi32>)   map_clauses(exit_release_or_enter_alloc) capture(ByRef) -> memref<?xi32> {name = ""}
    omp.target map_entries(%mapv1 -> %arg0, %mapv2 -> %arg1 : memref<?xi32>, memref<?xi32>) {
    ^bb0(%arg0: memref<?xi32>, %arg1: memref<?xi32>):
      omp.terminator
    }
    // CHECK: %[[MAP_C:.*]] = omp.map_info var_ptr(%[[VAL_1:.*]] : memref<?xi32>, tensor<?xi32>)   map_clauses(to) capture(ByRef) -> memref<?xi32> {name = ""}
    // CHECK: %[[MAP_D:.*]] = omp.map_info var_ptr(%[[VAL_2:.*]] : memref<?xi32>, tensor<?xi32>)   map_clauses(always, from) capture(ByRef) -> memref<?xi32> {name = ""}
    // CHECK: omp.target map_entries(%[[MAP_C]] -> {{.*}}, %[[MAP_D]] -> {{.*}} : memref<?xi32>, memref<?xi32>) {
    %mapv3 = omp.map_info var_ptr(%map1 : memref<?xi32>, tensor<?xi32>)   map_clauses(to) capture(ByRef) -> memref<?xi32> {name = ""}
    %mapv4 = omp.map_info var_ptr(%map2 : memref<?xi32>, tensor<?xi32>)   map_clauses(always, from) capture(ByRef) -> memref<?xi32> {name = ""}
    omp.target map_entries(%mapv3 -> %arg0, %mapv4 -> %arg1 : memref<?xi32>, memref<?xi32>) {
    ^bb0(%arg0: memref<?xi32>, %arg1: memref<?xi32>):
      omp.terminator
    }
    // CHECK: omp.barrier
    omp.barrier

    return
}

// CHECK-LABEL: omp_target_data
func.func @omp_target_data (%if_cond : i1, %device : si32, %device_ptr: memref<i32>, %device_addr: memref<?xi32>, %map1: memref<?xi32>, %map2: memref<?xi32>) -> () {
    // CHECK: %[[MAP_A:.*]] = omp.map_info var_ptr(%[[VAL_2:.*]] : memref<?xi32>, tensor<?xi32>)   map_clauses(always, from) capture(ByRef) -> memref<?xi32> {name = ""}
    // CHECK: omp.target_data if(%[[VAL_0:.*]] : i1) device(%[[VAL_1:.*]] : si32) map_entries(%[[MAP_A]] : memref<?xi32>)
    %mapv1 = omp.map_info var_ptr(%map1 : memref<?xi32>, tensor<?xi32>)   map_clauses(always, from) capture(ByRef) -> memref<?xi32> {name = ""}
    omp.target_data if(%if_cond : i1) device(%device : si32) map_entries(%mapv1 : memref<?xi32>){}

    // CHECK: %[[MAP_A:.*]] = omp.map_info var_ptr(%[[VAL_2:.*]] : memref<?xi32>, tensor<?xi32>)   map_clauses(close, present, to) capture(ByRef) -> memref<?xi32> {name = ""}
    // CHECK: omp.target_data map_entries(%[[MAP_A]] : memref<?xi32>) use_device_ptr(%[[VAL_3:.*]] : memref<i32>) use_device_addr(%[[VAL_4:.*]] : memref<?xi32>)
    %mapv2 = omp.map_info var_ptr(%map1 : memref<?xi32>, tensor<?xi32>)   map_clauses(close, present, to) capture(ByRef) -> memref<?xi32> {name = ""}
    omp.target_data map_entries(%mapv2 : memref<?xi32>) use_device_ptr(%device_ptr : memref<i32>) use_device_addr(%device_addr : memref<?xi32>) {}

    // CHECK: %[[MAP_A:.*]] = omp.map_info var_ptr(%[[VAL_1:.*]] : memref<?xi32>, tensor<?xi32>)   map_clauses(tofrom) capture(ByRef) -> memref<?xi32> {name = ""}
    // CHECK: %[[MAP_B:.*]] = omp.map_info var_ptr(%[[VAL_2:.*]] : memref<?xi32>, tensor<?xi32>)   map_clauses(exit_release_or_enter_alloc) capture(ByRef) -> memref<?xi32> {name = ""}
    // CHECK: omp.target_data map_entries(%[[MAP_A]], %[[MAP_B]] : memref<?xi32>, memref<?xi32>)
    %mapv3 = omp.map_info var_ptr(%map1 : memref<?xi32>, tensor<?xi32>)   map_clauses(tofrom) capture(ByRef) -> memref<?xi32> {name = ""}
    %mapv4 = omp.map_info var_ptr(%map2 : memref<?xi32>, tensor<?xi32>)   map_clauses(exit_release_or_enter_alloc) capture(ByRef) -> memref<?xi32> {name = ""}
    omp.target_data map_entries(%mapv3, %mapv4 : memref<?xi32>, memref<?xi32>) {}

    // CHECK: %[[MAP_A:.*]] = omp.map_info var_ptr(%[[VAL_3:.*]] : memref<?xi32>, tensor<?xi32>)   map_clauses(exit_release_or_enter_alloc) capture(ByRef) -> memref<?xi32> {name = ""}
    // CHECK: omp.target_enter_data if(%[[VAL_0:.*]] : i1) device(%[[VAL_1:.*]] : si32) nowait map_entries(%[[MAP_A]] : memref<?xi32>)
    %mapv5 = omp.map_info var_ptr(%map1 : memref<?xi32>, tensor<?xi32>)   map_clauses(exit_release_or_enter_alloc) capture(ByRef) -> memref<?xi32> {name = ""}
    omp.target_enter_data if(%if_cond : i1) device(%device : si32) nowait map_entries(%mapv5 : memref<?xi32>)

    // CHECK: %[[MAP_A:.*]] = omp.map_info var_ptr(%[[VAL_3:.*]] : memref<?xi32>, tensor<?xi32>)   map_clauses(exit_release_or_enter_alloc) capture(ByRef) -> memref<?xi32> {name = ""}
    // CHECK: omp.target_exit_data if(%[[VAL_0:.*]] : i1) device(%[[VAL_1:.*]] : si32) nowait map_entries(%[[MAP_A]] : memref<?xi32>)
    %mapv6 = omp.map_info var_ptr(%map2 : memref<?xi32>, tensor<?xi32>)   map_clauses(exit_release_or_enter_alloc) capture(ByRef) -> memref<?xi32> {name = ""}
    omp.target_exit_data if(%if_cond : i1) device(%device : si32) nowait map_entries(%mapv6 : memref<?xi32>)

    return
}

// CHECK-LABEL: omp_target_pretty
func.func @omp_target_pretty(%if_cond : i1, %device : si32,  %num_threads : i32) -> () {
    // CHECK: omp.target if({{.*}}) device({{.*}})
    omp.target if(%if_cond) device(%device : si32) {
      omp.terminator
    }

    // CHECK: omp.target if({{.*}}) device({{.*}}) nowait
    omp.target if(%if_cond) device(%device : si32) thread_limit(%num_threads : i32) nowait {
      omp.terminator
    }

    return
}

// CHECK: omp.reduction.declare
// CHECK-LABEL: @add_f32
// CHECK: : f32
// CHECK: init
// CHECK: ^{{.+}}(%{{.+}}: f32):
// CHECK:   omp.yield
// CHECK: combiner
// CHECK: ^{{.+}}(%{{.+}}: f32, %{{.+}}: f32):
// CHECK:   omp.yield
// CHECK: atomic
// CHECK: ^{{.+}}(%{{.+}}: !llvm.ptr, %{{.+}}: !llvm.ptr):
// CHECK:  omp.yield
omp.reduction.declare @add_f32 : f32
init {
^bb0(%arg: f32):
  %0 = arith.constant 0.0 : f32
  omp.yield (%0 : f32)
}
combiner {
^bb1(%arg0: f32, %arg1: f32):
  %1 = arith.addf %arg0, %arg1 : f32
  omp.yield (%1 : f32)
}
atomic {
^bb2(%arg2: !llvm.ptr, %arg3: !llvm.ptr):
  %2 = llvm.load %arg3 : !llvm.ptr -> f32
  llvm.atomicrmw fadd %arg2, %2 monotonic : !llvm.ptr, f32
  omp.yield
}

// CHECK-LABEL: func @wsloop_reduction
func.func @wsloop_reduction(%lb : index, %ub : index, %step : index) {
  %c1 = arith.constant 1 : i32
  %0 = llvm.alloca %c1 x i32 : (i32) -> !llvm.ptr
  // CHECK: reduction(@add_f32 -> %{{.+}} : !llvm.ptr)
  omp.wsloop reduction(@add_f32 -> %0 : !llvm.ptr)
  for (%iv) : index = (%lb) to (%ub) step (%step) {
    %1 = arith.constant 2.0 : f32
    // CHECK: omp.reduction %{{.+}}, %{{.+}}
    omp.reduction %1, %0 : f32, !llvm.ptr
    omp.yield
  }
  return
}

// CHECK-LABEL: func @parallel_reduction
func.func @parallel_reduction() {
  %c1 = arith.constant 1 : i32
  %0 = llvm.alloca %c1 x i32 : (i32) -> !llvm.ptr
  // CHECK: omp.parallel reduction(@add_f32 {{.+}} -> {{.+}} : !llvm.ptr)
  omp.parallel reduction(@add_f32 %0 -> %prv : !llvm.ptr) {
    %1 = arith.constant 2.0 : f32
    %2 = llvm.load %prv : !llvm.ptr -> f32
    // CHECK: llvm.fadd %{{.*}}, %{{.*}} : f32
    %3 = llvm.fadd %1, %2 : f32
    llvm.store %3, %prv : f32, !llvm.ptr
    omp.terminator
  }
  return
}

// CHECK: func @parallel_wsloop_reduction
func.func @parallel_wsloop_reduction(%lb : index, %ub : index, %step : index) {
  %c1 = arith.constant 1 : i32
  %0 = llvm.alloca %c1 x i32 : (i32) -> !llvm.ptr
  // CHECK: omp.parallel reduction(@add_f32 %{{.*}} -> %{{.+}} : !llvm.ptr) {
  omp.parallel reduction(@add_f32 %0 -> %prv : !llvm.ptr) {
    // CHECK: omp.wsloop for (%{{.+}}) : index = (%{{.+}}) to (%{{.+}}) step (%{{.+}})
    omp.wsloop for (%iv) : index = (%lb) to (%ub) step (%step) {
      %1 = arith.constant 2.0 : f32
      %2 = llvm.load %prv : !llvm.ptr -> f32
      // CHECK: llvm.fadd %{{.+}}, %{{.+}} : f32
      llvm.fadd %1, %2 : f32
      // CHECK: omp.yield
      omp.yield
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: omp_teams
func.func @omp_teams(%lb : i32, %ub : i32, %if_cond : i1, %num_threads : i32,
                     %data_var : memref<i32>) -> () {
  // Test nesting inside of omp.target
  omp.target {
    // CHECK: omp.teams
    omp.teams {
      // CHECK: omp.terminator
      omp.terminator
    }
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.teams
  omp.teams {
    %0 = arith.constant 1 : i32
    // CHECK: omp.terminator
    omp.terminator
  }

  // Test num teams.
  // CHECK: omp.teams num_teams(%{{.+}} : i32 to %{{.+}} : i32)
  omp.teams num_teams(%lb : i32 to %ub : i32) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.teams num_teams( to %{{.+}} : i32)
  omp.teams num_teams(to %ub : i32) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // Test if.
  // CHECK: omp.teams if(%{{.+}})
  omp.teams if(%if_cond) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // Test thread limit.
  // CHECK: omp.teams thread_limit(%{{.+}} : i32)
  omp.teams thread_limit(%num_threads : i32) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // Test reduction.
  %c1 = arith.constant 1 : i32
  %0 = llvm.alloca %c1 x i32 : (i32) -> !llvm.ptr
  // CHECK: omp.teams reduction(@add_f32 -> %{{.+}} : !llvm.ptr) {
  omp.teams reduction(@add_f32 -> %0 : !llvm.ptr) {
    %1 = arith.constant 2.0 : f32
    // CHECK: omp.reduction %{{.+}}, %{{.+}}
    omp.reduction %1, %0 : f32, !llvm.ptr
    // CHECK: omp.terminator
    omp.terminator
  }

  // Test allocate.
  // CHECK: omp.teams allocate(%{{.+}} : memref<i32> -> %{{.+}} : memref<i32>)
  omp.teams allocate(%data_var : memref<i32> -> %data_var : memref<i32>) {
    // CHECK: omp.terminator
    omp.terminator
  }

  return
}

// CHECK-LABEL: func @sections_reduction
func.func @sections_reduction() {
  %c1 = arith.constant 1 : i32
  %0 = llvm.alloca %c1 x i32 : (i32) -> !llvm.ptr
  // CHECK: omp.sections reduction(@add_f32 -> {{.+}} : !llvm.ptr)
  omp.sections reduction(@add_f32 -> %0 : !llvm.ptr) {
    // CHECK: omp.section
    omp.section {
      %1 = arith.constant 2.0 : f32
      // CHECK: omp.reduction %{{.+}}, %{{.+}}
      omp.reduction %1, %0 : f32, !llvm.ptr
      omp.terminator
    }
    // CHECK: omp.section
    omp.section {
      %1 = arith.constant 3.0 : f32
      // CHECK: omp.reduction %{{.+}}, %{{.+}}
      omp.reduction %1, %0 : f32, !llvm.ptr
      omp.terminator
    }
    omp.terminator
  }
  return
}

// CHECK: omp.reduction.declare
// CHECK-LABEL: @add2_f32
omp.reduction.declare @add2_f32 : f32
// CHECK: init
init {
^bb0(%arg: f32):
  %0 = arith.constant 0.0 : f32
  omp.yield (%0 : f32)
}
// CHECK: combiner
combiner {
^bb1(%arg0: f32, %arg1: f32):
  %1 = arith.addf %arg0, %arg1 : f32
  omp.yield (%1 : f32)
}
// CHECK-NOT: atomic

// CHECK-LABEL: func @wsloop_reduction2
func.func @wsloop_reduction2(%lb : index, %ub : index, %step : index) {
  %0 = memref.alloca() : memref<1xf32>
  // CHECK: omp.wsloop reduction(@add2_f32 -> %{{.+}} : memref<1xf32>)
  omp.wsloop reduction(@add2_f32 -> %0 : memref<1xf32>)
  for (%iv) : index = (%lb) to (%ub) step (%step) {
    %1 = arith.constant 2.0 : f32
    // CHECK: omp.reduction
    omp.reduction %1, %0 : f32, memref<1xf32>
    omp.yield
  }
  return
}

// CHECK-LABEL: func @parallel_reduction2
func.func @parallel_reduction2() {
  %0 = memref.alloca() : memref<1xf32>
  // CHECK: omp.parallel reduction(@add2_f32 %{{.+}} -> %{{.+}} : memref<1xf32>)
  omp.parallel reduction(@add2_f32 %0 -> %prv : memref<1xf32>) {
    %1 = arith.constant 2.0 : f32
    %2 = arith.constant 0 : index
    %3 = memref.load %prv[%2] : memref<1xf32>
    // CHECK: llvm.fadd
    %4 = llvm.fadd %1, %3 : f32
    memref.store %4, %prv[%2] : memref<1xf32>
    omp.terminator
  }
  return
}

// CHECK: func @parallel_wsloop_reduction2
func.func @parallel_wsloop_reduction2(%lb : index, %ub : index, %step : index) {
  %c1 = arith.constant 1 : i32
  %0 = llvm.alloca %c1 x i32 : (i32) -> !llvm.ptr
  // CHECK: omp.parallel reduction(@add2_f32 %{{.*}} -> %{{.+}} : !llvm.ptr) {
  omp.parallel reduction(@add2_f32 %0 -> %prv : !llvm.ptr) {
    // CHECK: omp.wsloop for (%{{.+}}) : index = (%{{.+}}) to (%{{.+}}) step (%{{.+}})
    omp.wsloop for (%iv) : index = (%lb) to (%ub) step (%step) {
      %1 = arith.constant 2.0 : f32
      %2 = llvm.load %prv : !llvm.ptr -> f32
      // CHECK: llvm.fadd %{{.+}}, %{{.+}} : f32
      %3 = llvm.fadd %1, %2 : f32
      // CHECK: omp.yield
      omp.yield
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: func @sections_reduction2
func.func @sections_reduction2() {
  %0 = memref.alloca() : memref<1xf32>
  // CHECK: omp.sections reduction(@add2_f32 -> %{{.+}} : memref<1xf32>)
  omp.sections reduction(@add2_f32 -> %0 : memref<1xf32>) {
    omp.section {
      %1 = arith.constant 2.0 : f32
      // CHECK: omp.reduction
      omp.reduction %1, %0 : f32, memref<1xf32>
      omp.terminator
    }
    omp.section {
      %1 = arith.constant 2.0 : f32
      // CHECK: omp.reduction
      omp.reduction %1, %0 : f32, memref<1xf32>
      omp.terminator
    }
    omp.terminator
  }
  return
}

// CHECK: omp.critical.declare @mutex1 hint(uncontended)
omp.critical.declare @mutex1 hint(uncontended)
// CHECK: omp.critical.declare @mutex2 hint(contended)
omp.critical.declare @mutex2 hint(contended)
// CHECK: omp.critical.declare @mutex3 hint(nonspeculative)
omp.critical.declare @mutex3 hint(nonspeculative)
// CHECK: omp.critical.declare @mutex4 hint(speculative)
omp.critical.declare @mutex4 hint(speculative)
// CHECK: omp.critical.declare @mutex5 hint(uncontended, nonspeculative)
omp.critical.declare @mutex5 hint(uncontended, nonspeculative)
// CHECK: omp.critical.declare @mutex6 hint(contended, nonspeculative)
omp.critical.declare @mutex6 hint(contended, nonspeculative)
// CHECK: omp.critical.declare @mutex7 hint(uncontended, speculative)
omp.critical.declare @mutex7 hint(uncontended, speculative)
// CHECK: omp.critical.declare @mutex8 hint(contended, speculative)
omp.critical.declare @mutex8 hint(contended, speculative)
// CHECK: omp.critical.declare @mutex9
omp.critical.declare @mutex9 hint(none)
// CHECK: omp.critical.declare @mutex10
omp.critical.declare @mutex10


// CHECK-LABEL: omp_critical
func.func @omp_critical() -> () {
  // CHECK: omp.critical
  omp.critical {
    omp.terminator
  }

  // CHECK: omp.critical(@{{.*}})
  omp.critical(@mutex1) {
    omp.terminator
  }
  return
}

func.func @omp_ordered(%arg1 : i32, %arg2 : i32, %arg3 : i32,
    %vec0 : i64, %vec1 : i64, %vec2 : i64, %vec3 : i64) -> () {
  // CHECK: omp.ordered_region
  omp.ordered_region {
    // CHECK: omp.terminator
    omp.terminator
  }

  omp.wsloop ordered(0)
  for (%0) : i32 = (%arg1) to (%arg2) step (%arg3)  {
    omp.ordered_region {
      omp.terminator
    }
    omp.yield
  }

  omp.wsloop ordered(1)
  for (%0) : i32 = (%arg1) to (%arg2) step (%arg3) {
    // Only one DEPEND(SINK: vec) clause
    // CHECK: omp.ordered depend_type(dependsink) depend_vec(%{{.*}} : i64) {num_loops_val = 1 : i64}
    omp.ordered depend_type(dependsink) depend_vec(%vec0 : i64) {num_loops_val = 1 : i64}

    // CHECK: omp.ordered depend_type(dependsource) depend_vec(%{{.*}} : i64) {num_loops_val = 1 : i64}
    omp.ordered depend_type(dependsource) depend_vec(%vec0 : i64) {num_loops_val = 1 : i64}

    omp.yield
  }

  omp.wsloop ordered(2)
  for (%0) : i32 = (%arg1) to (%arg2) step (%arg3) {
    // Multiple DEPEND(SINK: vec) clauses
    // CHECK: omp.ordered depend_type(dependsink) depend_vec(%{{.*}}, %{{.*}}, %{{.*}}, %{{.*}} : i64, i64, i64, i64) {num_loops_val = 2 : i64}
    omp.ordered depend_type(dependsink) depend_vec(%vec0, %vec1, %vec2, %vec3 : i64, i64, i64, i64) {num_loops_val = 2 : i64}

    // CHECK: omp.ordered depend_type(dependsource) depend_vec(%{{.*}}, %{{.*}} : i64, i64) {num_loops_val = 2 : i64}
    omp.ordered depend_type(dependsource) depend_vec(%vec0, %vec1 : i64, i64) {num_loops_val = 2 : i64}

    omp.yield
  }

  return
}

// CHECK-LABEL: omp_atomic_read
// CHECK-SAME: (%[[v:.*]]: memref<i32>, %[[x:.*]]: memref<i32>)
func.func @omp_atomic_read(%v: memref<i32>, %x: memref<i32>) {
  // CHECK: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  omp.atomic.read %v = %x : memref<i32>, i32
  // CHECK: omp.atomic.read %[[v]] = %[[x]] memory_order(seq_cst) : memref<i32>, i32
  omp.atomic.read %v = %x memory_order(seq_cst) : memref<i32>, i32
  // CHECK: omp.atomic.read %[[v]] = %[[x]] memory_order(acquire) : memref<i32>, i32
  omp.atomic.read %v = %x memory_order(acquire) : memref<i32>, i32
  // CHECK: omp.atomic.read %[[v]] = %[[x]] memory_order(relaxed) : memref<i32>, i32
  omp.atomic.read %v = %x memory_order(relaxed) : memref<i32>, i32
  // CHECK: omp.atomic.read %[[v]] = %[[x]] hint(contended, nonspeculative) : memref<i32>, i32
  omp.atomic.read %v = %x hint(nonspeculative, contended) : memref<i32>, i32
  // CHECK: omp.atomic.read %[[v]] = %[[x]] memory_order(seq_cst) hint(contended, speculative) : memref<i32>, i32
  omp.atomic.read %v = %x hint(speculative, contended) memory_order(seq_cst) : memref<i32>, i32
  // CHECK: omp.atomic.read %[[v]] = %[[x]] memory_order(seq_cst) : memref<i32>, i32
  omp.atomic.read %v = %x hint(none) memory_order(seq_cst) : memref<i32>, i32
  return
}

// CHECK-LABEL: omp_atomic_write
// CHECK-SAME: (%[[ADDR:.*]]: memref<i32>, %[[VAL:.*]]: i32)
func.func @omp_atomic_write(%addr : memref<i32>, %val : i32) {
  // CHECK: omp.atomic.write %[[ADDR]] = %[[VAL]] : memref<i32>, i32
  omp.atomic.write %addr = %val : memref<i32>, i32
  // CHECK: omp.atomic.write %[[ADDR]] = %[[VAL]] memory_order(seq_cst) : memref<i32>, i32
  omp.atomic.write %addr = %val memory_order(seq_cst) : memref<i32>, i32
  // CHECK: omp.atomic.write %[[ADDR]] = %[[VAL]] memory_order(release) : memref<i32>, i32
  omp.atomic.write %addr = %val memory_order(release) : memref<i32>, i32
  // CHECK: omp.atomic.write %[[ADDR]] = %[[VAL]] memory_order(relaxed) : memref<i32>, i32
  omp.atomic.write %addr = %val memory_order(relaxed) : memref<i32>, i32
  // CHECK: omp.atomic.write %[[ADDR]] = %[[VAL]] hint(uncontended, speculative) : memref<i32>, i32
  omp.atomic.write %addr = %val hint(speculative, uncontended) : memref<i32>, i32
  // CHECK: omp.atomic.write %[[ADDR]] = %[[VAL]] : memref<i32>, i32
  omp.atomic.write %addr = %val hint(none) : memref<i32>, i32
  return
}

// CHECK-LABEL: omp_atomic_update
// CHECK-SAME: (%[[X:.*]]: memref<i32>, %[[EXPR:.*]]: i32, %[[XBOOL:.*]]: memref<i1>, %[[EXPRBOOL:.*]]: i1)
func.func @omp_atomic_update(%x : memref<i32>, %expr : i32, %xBool : memref<i1>, %exprBool : i1) {
  // CHECK: omp.atomic.update %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }
  // CHECK: omp.atomic.update %[[XBOOL]] : memref<i1>
  // CHECK-NEXT: (%[[XVAL:.*]]: i1):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.and %[[XVAL]], %[[EXPRBOOL]] : i1
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i1)
  omp.atomic.update %xBool : memref<i1> {
  ^bb0(%xval: i1):
    %newval = llvm.and %xval, %exprBool : i1
    omp.yield(%newval : i1)
  }
  // CHECK: omp.atomic.update %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.shl %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  // CHECK-NEXT: }
  omp.atomic.update %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.shl %xval, %expr : i32
    omp.yield(%newval : i32)
  }
  // CHECK: omp.atomic.update %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.intr.smax(%[[XVAL]], %[[EXPR]]) : (i32, i32) -> i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  // CHECK-NEXT: }
  omp.atomic.update %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.intr.smax(%xval, %expr) : (i32, i32) -> i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update %[[XBOOL]] : memref<i1>
  // CHECK-NEXT: (%[[XVAL:.*]]: i1):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.icmp "eq" %[[XVAL]], %[[EXPRBOOL]] : i1
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i1)
  // }
  omp.atomic.update %xBool : memref<i1> {
  ^bb0(%xval: i1):
    %newval = llvm.icmp "eq" %xval, %exprBool : i1
    omp.yield(%newval : i1)
  }

  // CHECK: omp.atomic.update %[[X]] : memref<i32> {
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   omp.yield(%[[XVAL]] : i32)
  // CHECK-NEXT: }
  omp.atomic.update %x : memref<i32> {
  ^bb0(%xval:i32):
    omp.yield(%xval:i32)
  }

  // CHECK: omp.atomic.update %[[X]] : memref<i32> {
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   omp.yield(%{{.+}} : i32)
  // CHECK-NEXT: }
  %const = arith.constant 42 : i32
  omp.atomic.update %x : memref<i32> {
  ^bb0(%xval:i32):
    omp.yield(%const:i32)
  }

  // CHECK: omp.atomic.update %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update hint(none) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update hint(uncontended) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update hint(uncontended) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update hint(contended) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update hint(contended) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update hint(nonspeculative) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update hint(nonspeculative) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update hint(speculative) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update hint(speculative) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update hint(uncontended, nonspeculative) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update hint(uncontended, nonspeculative) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update hint(contended, nonspeculative) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update hint(contended, nonspeculative) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update hint(uncontended, speculative) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update hint(uncontended, speculative) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update hint(contended, speculative) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update hint(contended, speculative) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update memory_order(seq_cst) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update memory_order(seq_cst) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update memory_order(release) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update memory_order(release) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update memory_order(relaxed) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update memory_order(relaxed) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  // CHECK: omp.atomic.update memory_order(seq_cst) hint(uncontended, speculative) %[[X]] : memref<i32>
  // CHECK-NEXT: (%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   %[[NEWVAL:.*]] = llvm.add %[[XVAL]], %[[EXPR]] : i32
  // CHECK-NEXT:   omp.yield(%[[NEWVAL]] : i32)
  omp.atomic.update memory_order(seq_cst) hint(uncontended, speculative) %x : memref<i32> {
  ^bb0(%xval: i32):
    %newval = llvm.add %xval, %expr : i32
    omp.yield(%newval : i32)
  }

  return
}

// CHECK-LABEL: omp_atomic_capture
// CHECK-SAME: (%[[v:.*]]: memref<i32>, %[[x:.*]]: memref<i32>, %[[expr:.*]]: i32)
func.func @omp_atomic_capture(%v: memref<i32>, %x: memref<i32>, %expr: i32) {
  // CHECK: omp.atomic.capture {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture{
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }
  // CHECK: omp.atomic.capture {
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: }
  omp.atomic.capture{
    omp.atomic.read %v = %x : memref<i32>, i32
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
  }
  // CHECK: omp.atomic.capture {
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: omp.atomic.write %[[x]] = %[[expr]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture{
    omp.atomic.read %v = %x : memref<i32>, i32
    omp.atomic.write %x = %expr : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture hint(none) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture hint(uncontended) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture hint(uncontended) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture hint(contended) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture hint(contended) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture hint(nonspeculative) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture hint(nonspeculative) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture hint(speculative) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture hint(speculative) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture hint(uncontended, nonspeculative) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture hint(uncontended, nonspeculative) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture hint(contended, nonspeculative) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture hint(contended, nonspeculative) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture hint(uncontended, speculative) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture hint(uncontended, speculative) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture hint(contended, speculative) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>
  // CHECK-NEXT: }
  omp.atomic.capture hint(contended, speculative) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture memory_order(seq_cst) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>
  // CHECK-NEXT: }
  omp.atomic.capture memory_order(seq_cst) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture memory_order(acq_rel) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>
  // CHECK-NEXT: }
  omp.atomic.capture memory_order(acq_rel) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture memory_order(acquire) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture memory_order(acquire) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture memory_order(release) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture memory_order(release) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture memory_order(relaxed) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture memory_order(relaxed) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  // CHECK: omp.atomic.capture memory_order(seq_cst) hint(contended, speculative) {
  // CHECK-NEXT: omp.atomic.update %[[x]] : memref<i32>
  // CHECK-NEXT: (%[[xval:.*]]: i32):
  // CHECK-NEXT:   %[[newval:.*]] = llvm.add %[[xval]], %[[expr]] : i32
  // CHECK-NEXT:   omp.yield(%[[newval]] : i32)
  // CHECK-NEXT: }
  // CHECK-NEXT: omp.atomic.read %[[v]] = %[[x]] : memref<i32>, i32
  // CHECK-NEXT: }
  omp.atomic.capture hint(contended, speculative) memory_order(seq_cst) {
    omp.atomic.update %x : memref<i32> {
    ^bb0(%xval: i32):
      %newval = llvm.add %xval, %expr : i32
      omp.yield(%newval : i32)
    }
    omp.atomic.read %v = %x : memref<i32>, i32
  }

  return
}

// CHECK-LABEL: omp_sectionsop
func.func @omp_sectionsop(%data_var1 : memref<i32>, %data_var2 : memref<i32>,
                     %data_var3 : memref<i32>, %redn_var : !llvm.ptr) {
  // CHECK: omp.sections allocate(%{{.*}} : memref<i32> -> %{{.*}} : memref<i32>)
  "omp.sections" (%data_var1, %data_var1) ({
    // CHECK: omp.terminator
    omp.terminator
  }) {operandSegmentSizes = array<i32: 0,1,1>} : (memref<i32>, memref<i32>) -> ()

    // CHECK: omp.sections reduction(@add_f32 -> %{{.*}} : !llvm.ptr)
  "omp.sections" (%redn_var) ({
    // CHECK: omp.terminator
    omp.terminator
  }) {operandSegmentSizes = array<i32: 1,0,0>, reductions=[@add_f32]} : (!llvm.ptr) -> ()

  // CHECK: omp.sections nowait {
  omp.sections nowait {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.sections reduction(@add_f32 -> %{{.*}} : !llvm.ptr) {
  omp.sections reduction(@add_f32 -> %redn_var : !llvm.ptr) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.sections allocate(%{{.*}} : memref<i32> -> %{{.*}} : memref<i32>)
  omp.sections allocate(%data_var1 : memref<i32> -> %data_var1 : memref<i32>) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.sections nowait
  omp.sections nowait {
    // CHECK: omp.section
    omp.section {
      // CHECK: %{{.*}} = "test.payload"() : () -> i32
      %1 = "test.payload"() : () -> i32
      // CHECK: %{{.*}} = "test.payload"() : () -> i32
      %2 = "test.payload"() : () -> i32
      // CHECK: %{{.*}} = "test.payload"(%{{.*}}, %{{.*}}) : (i32, i32) -> i32
      %3 = "test.payload"(%1, %2) : (i32, i32) -> i32
    }
    // CHECK: omp.section
    omp.section {
      // CHECK: %{{.*}} = "test.payload"(%{{.*}}) : (!llvm.ptr) -> i32
      %1 = "test.payload"(%redn_var) : (!llvm.ptr) -> i32
    }
    // CHECK: omp.section
    omp.section {
      // CHECK: "test.payload"(%{{.*}}) : (!llvm.ptr) -> ()
      "test.payload"(%redn_var) : (!llvm.ptr) -> ()
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: func @omp_single
func.func @omp_single() {
  omp.parallel {
    // CHECK: omp.single {
    omp.single {
      "test.payload"() : () -> ()
      // CHECK: omp.terminator
      omp.terminator
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: func @omp_single_nowait
func.func @omp_single_nowait() {
  omp.parallel {
    // CHECK: omp.single nowait {
    omp.single nowait {
      "test.payload"() : () -> ()
      // CHECK: omp.terminator
      omp.terminator
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: func @omp_single_allocate
func.func @omp_single_allocate(%data_var: memref<i32>) {
  omp.parallel {
    // CHECK: omp.single allocate(%{{.*}} : memref<i32> -> %{{.*}} : memref<i32>) {
    omp.single allocate(%data_var : memref<i32> -> %data_var : memref<i32>) {
      "test.payload"() : () -> ()
      // CHECK: omp.terminator
      omp.terminator
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: func @omp_single_allocate_nowait
func.func @omp_single_allocate_nowait(%data_var: memref<i32>) {
  omp.parallel {
    // CHECK: omp.single allocate(%{{.*}} : memref<i32> -> %{{.*}} : memref<i32>) nowait {
    omp.single allocate(%data_var : memref<i32> -> %data_var : memref<i32>) nowait {
      "test.payload"() : () -> ()
      // CHECK: omp.terminator
      omp.terminator
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: func @omp_single_multiple_blocks
func.func @omp_single_multiple_blocks() {
  // CHECK: omp.single {
  omp.single {
    cf.br ^bb2
    ^bb2:
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: @omp_task
// CHECK-SAME: (%[[bool_var:.*]]: i1, %[[i64_var:.*]]: i64, %[[i32_var:.*]]: i32, %[[data_var:.*]]: memref<i32>)
func.func @omp_task(%bool_var: i1, %i64_var: i64, %i32_var: i32, %data_var: memref<i32>) {

  // Checking simple task
  // CHECK: omp.task {
  omp.task {
    // CHECK: "test.foo"() : () -> ()
    "test.foo"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }

  // Checking `if` clause
  // CHECK: omp.task if(%[[bool_var]]) {
  omp.task if(%bool_var) {
    // CHECK: "test.foo"() : () -> ()
    "test.foo"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }

  // Checking `final` clause
  // CHECK: omp.task final(%[[bool_var]]) {
  omp.task final(%bool_var) {
    // CHECK: "test.foo"() : () -> ()
    "test.foo"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }

  // Checking `untied` clause
  // CHECK: omp.task untied {
  omp.task untied {
    // CHECK: "test.foo"() : () -> ()
    "test.foo"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }

  // Checking `in_reduction` clause
  %c1 = arith.constant 1 : i32
  // CHECK: %[[redn_var1:.*]] = llvm.alloca %{{.*}} x f32 : (i32) -> !llvm.ptr
  %0 = llvm.alloca %c1 x f32 : (i32) -> !llvm.ptr
  // CHECK: %[[redn_var2:.*]] = llvm.alloca %{{.*}} x f32 : (i32) -> !llvm.ptr
  %1 = llvm.alloca %c1 x f32 : (i32) -> !llvm.ptr
  // CHECK: omp.task in_reduction(@add_f32 -> %[[redn_var1]] : !llvm.ptr, @add_f32 -> %[[redn_var2]] : !llvm.ptr) {
  omp.task in_reduction(@add_f32 -> %0 : !llvm.ptr, @add_f32 -> %1 : !llvm.ptr) {
    // CHECK: "test.foo"() : () -> ()
    "test.foo"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }

  // Checking priority clause
  // CHECK: omp.task priority(%[[i32_var]]) {
  omp.task priority(%i32_var) {
    // CHECK: "test.foo"() : () -> ()
    "test.foo"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }

  // Checking allocate clause
  // CHECK: omp.task allocate(%[[data_var]] : memref<i32> -> %[[data_var]] : memref<i32>) {
  omp.task allocate(%data_var : memref<i32> -> %data_var : memref<i32>) {
    // CHECK: "test.foo"() : () -> ()
    "test.foo"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }

  // Checking multiple clauses
  // CHECK: omp.task if(%[[bool_var]]) final(%[[bool_var]]) untied
  omp.task if(%bool_var) final(%bool_var) untied
      // CHECK-SAME: in_reduction(@add_f32 -> %[[redn_var1]] : !llvm.ptr, @add_f32 -> %[[redn_var2]] : !llvm.ptr)
      in_reduction(@add_f32 -> %0 : !llvm.ptr, @add_f32 -> %1 : !llvm.ptr)
      // CHECK-SAME: priority(%[[i32_var]])
      priority(%i32_var)
      // CHECK-SAME: allocate(%[[data_var]] : memref<i32> -> %[[data_var]] : memref<i32>)
      allocate(%data_var : memref<i32> -> %data_var : memref<i32>) {
    // CHECK: "test.foo"() : () -> ()
    "test.foo"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }

  return
}

// CHECK-LABEL: @omp_task_depend
// CHECK-SAME: (%arg0: memref<i32>, %arg1: memref<i32>) {
func.func @omp_task_depend(%arg0: memref<i32>, %arg1: memref<i32>) {
  // CHECK:  omp.task   depend(taskdependin -> %arg0 : memref<i32>, taskdependin -> %arg1 : memref<i32>, taskdependinout -> %arg0 : memref<i32>) {
  omp.task   depend(taskdependin -> %arg0 : memref<i32>, taskdependin -> %arg1 : memref<i32>, taskdependinout -> %arg0 : memref<i32>) {
    // CHECK: "test.foo"() : () -> ()
    "test.foo"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}


// CHECK-LABEL: @omp_target_depend
// CHECK-SAME: (%arg0: memref<i32>, %arg1: memref<i32>) {
func.func @omp_target_depend(%arg0: memref<i32>, %arg1: memref<i32>) {
  // CHECK:  omp.target depend(taskdependin -> %arg0 : memref<i32>, taskdependin -> %arg1 : memref<i32>, taskdependinout -> %arg0 : memref<i32>) {
  omp.target depend(taskdependin -> %arg0 : memref<i32>, taskdependin -> %arg1 : memref<i32>, taskdependinout -> %arg0 : memref<i32>) {
    // CHECK: omp.terminator
    omp.terminator
  } {operandSegmentSizes = array<i32: 0,0,0,3,0>}
  return
}

func.func @omp_threadprivate() {
  %0 = arith.constant 1 : i32
  %1 = arith.constant 2 : i32
  %2 = arith.constant 3 : i32

  // CHECK: [[ARG0:%.*]] = llvm.mlir.addressof @_QFsubEx : !llvm.ptr
  // CHECK: {{.*}} = omp.threadprivate [[ARG0]] : !llvm.ptr -> !llvm.ptr
  %3 = llvm.mlir.addressof @_QFsubEx : !llvm.ptr
  %4 = omp.threadprivate %3 : !llvm.ptr -> !llvm.ptr
  llvm.store %0, %4 : i32, !llvm.ptr

  // CHECK:  omp.parallel
  // CHECK:    {{.*}} = omp.threadprivate [[ARG0]] : !llvm.ptr -> !llvm.ptr
  omp.parallel  {
    %5 = omp.threadprivate %3 : !llvm.ptr -> !llvm.ptr
    llvm.store %1, %5 : i32, !llvm.ptr
    omp.terminator
  }
  llvm.store %2, %4 : i32, !llvm.ptr
  return
}

llvm.mlir.global internal @_QFsubEx() : i32

func.func @omp_cancel_parallel(%if_cond : i1) -> () {
  // Test with optional operand; if_expr.
  omp.parallel {
    // CHECK: omp.cancel cancellation_construct_type(parallel) if(%{{.*}})
    omp.cancel cancellation_construct_type(parallel) if(%if_cond)
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

func.func @omp_cancel_wsloop(%lb : index, %ub : index, %step : index) {
  omp.wsloop
  for (%iv) : index = (%lb) to (%ub) step (%step) {
    // CHECK: omp.cancel cancellation_construct_type(loop)
    omp.cancel cancellation_construct_type(loop)
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

func.func @omp_cancel_sections() -> () {
  omp.sections {
    omp.section {
      // CHECK: omp.cancel cancellation_construct_type(sections)
      omp.cancel cancellation_construct_type(sections)
      omp.terminator
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

func.func @omp_cancellationpoint_parallel() -> () {
  omp.parallel {
    // CHECK: omp.cancellationpoint cancellation_construct_type(parallel)
    omp.cancellationpoint cancellation_construct_type(parallel)
    // CHECK: omp.cancel cancellation_construct_type(parallel)
    omp.cancel cancellation_construct_type(parallel)
    omp.terminator
  }
  return
}

func.func @omp_cancellationpoint_wsloop(%lb : index, %ub : index, %step : index) {
  omp.wsloop
  for (%iv) : index = (%lb) to (%ub) step (%step) {
    // CHECK: omp.cancellationpoint cancellation_construct_type(loop)
    omp.cancellationpoint cancellation_construct_type(loop)
    // CHECK: omp.cancel cancellation_construct_type(loop)
    omp.cancel cancellation_construct_type(loop)
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

func.func @omp_cancellationpoint_sections() -> () {
  omp.sections {
    omp.section {
      // CHECK: omp.cancellationpoint cancellation_construct_type(sections)
      omp.cancellationpoint cancellation_construct_type(sections)
      // CHECK: omp.cancel cancellation_construct_type(sections)
      omp.cancel cancellation_construct_type(sections)
      omp.terminator
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: @omp_taskgroup_no_tasks
func.func @omp_taskgroup_no_tasks() -> () {

  // CHECK: omp.taskgroup
  omp.taskgroup {
    // CHECK: "test.foo"() : () -> ()
    "test.foo"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: @omp_taskgroup_multiple_tasks
func.func @omp_taskgroup_multiple_tasks() -> () {
  // CHECK: omp.taskgroup
  omp.taskgroup {
    // CHECK: omp.task
    omp.task {
      "test.foo"() : () -> ()
      // CHECK: omp.terminator
      omp.terminator
    }
    // CHECK: omp.task
    omp.task {
      "test.foo"() : () -> ()
      // CHECK: omp.terminator
      omp.terminator
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: @omp_taskgroup_clauses
func.func @omp_taskgroup_clauses() -> () {
  %testmemref = "test.memref"() : () -> (memref<i32>)
  %testf32 = "test.f32"() : () -> (!llvm.ptr)
  // CHECK: omp.taskgroup task_reduction(@add_f32 -> %{{.+}}: !llvm.ptr) allocate(%{{.+}}: memref<i32> -> %{{.+}}: memref<i32>)
  omp.taskgroup allocate(%testmemref : memref<i32> -> %testmemref : memref<i32>) task_reduction(@add_f32 -> %testf32 : !llvm.ptr) {
    // CHECK: omp.task
    omp.task {
      "test.foo"() : () -> ()
      // CHECK: omp.terminator
      omp.terminator
    }
    // CHECK: omp.task
    omp.task {
      "test.foo"() : () -> ()
      // CHECK: omp.terminator
      omp.terminator
    }
    // CHECK: omp.terminator
    omp.terminator
  }
  return
}

// CHECK-LABEL: @omp_taskloop
func.func @omp_taskloop(%lb: i32, %ub: i32, %step: i32) -> () {

  // CHECK: omp.taskloop for (%{{.+}}) : i32 = (%{{.+}}) to (%{{.+}}) step (%{{.+}}) {
  omp.taskloop for (%i) : i32 = (%lb) to (%ub) step (%step)  {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.taskloop for (%{{.+}}) : i32 = (%{{.+}}) to (%{{.+}}) step (%{{.+}}) {
  omp.taskloop for (%i) : i32 = (%lb) to (%ub) step (%step)  {
    // CHECK: test.op1
    "test.op1"(%lb) : (i32) -> ()
    // CHECK: test.op2
    "test.op2"() : () -> ()
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.taskloop for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.taskloop for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) inclusive step (%{{.+}}, %{{.+}}) {
  omp.taskloop for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) inclusive step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  %testbool = "test.bool"() : () -> (i1)

  // CHECK: omp.taskloop if(%{{[^)]+}})
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop if(%testbool)
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.taskloop final(%{{[^)]+}})
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop final(%testbool)
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.taskloop untied
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop untied
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.taskloop mergeable
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop mergeable
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  %testf32 = "test.f32"() : () -> (!llvm.ptr)
  %testf32_2 = "test.f32"() : () -> (!llvm.ptr)
  // CHECK: omp.taskloop in_reduction(@add_f32 -> %{{.+}} : !llvm.ptr, @add_f32 -> %{{.+}} : !llvm.ptr)
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop in_reduction(@add_f32 -> %testf32 : !llvm.ptr, @add_f32 -> %testf32_2 : !llvm.ptr)
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.taskloop reduction(@add_f32 -> %{{.+}} : !llvm.ptr, @add_f32 -> %{{.+}} : !llvm.ptr)
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop reduction(@add_f32 -> %testf32 : !llvm.ptr, @add_f32 -> %testf32_2 : !llvm.ptr)
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.taskloop in_reduction(@add_f32 -> %{{.+}} : !llvm.ptr) reduction(@add_f32 -> %{{.+}} : !llvm.ptr)
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop in_reduction(@add_f32 -> %testf32 : !llvm.ptr) reduction(@add_f32 -> %testf32_2 : !llvm.ptr)
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  %testi32 = "test.i32"() : () -> (i32)
  // CHECK: omp.taskloop priority(%{{[^:]+}}: i32)
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop priority(%testi32: i32)
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  %testmemref = "test.memref"() : () -> (memref<i32>)
  // CHECK: omp.taskloop allocate(%{{.+}} : memref<i32> -> %{{.+}} : memref<i32>)
  omp.taskloop allocate(%testmemref : memref<i32> -> %testmemref : memref<i32>)
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  %testi64 = "test.i64"() : () -> (i64)
  // CHECK: omp.taskloop grain_size(%{{[^:]+}}: i64)
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop grain_size(%testi64: i64)
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.taskloop num_tasks(%{{[^:]+}}: i64)
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop num_tasks(%testi64: i64)
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: omp.taskloop nogroup
  // CHECK-SAME: for (%{{.+}}, %{{.+}}) : i32 = (%{{.+}}, %{{.+}}) to (%{{.+}}, %{{.+}}) step (%{{.+}}, %{{.+}}) {
  omp.taskloop nogroup
  for (%i, %j) : i32 = (%lb, %ub) to (%ub, %lb) step (%step, %step) {
    // CHECK: omp.terminator
    omp.terminator
  }

  // CHECK: return
  return
}

// CHECK: func.func @omp_requires_one
// CHECK-SAME: omp.requires = #omp<clause_requires reverse_offload>
func.func @omp_requires_one() -> ()
    attributes {omp.requires = #omp<clause_requires reverse_offload>} {
  return
}

// CHECK: func.func @omp_requires_multiple
// CHECK-SAME: omp.requires = #omp<clause_requires unified_address|dynamic_allocators>
func.func @omp_requires_multiple() -> ()
    attributes {omp.requires = #omp<clause_requires unified_address|dynamic_allocators>} {
  return
}

// -----

// CHECK-LABEL: @opaque_pointers_atomic_rwu
// CHECK-SAME: (%[[v:.*]]: !llvm.ptr, %[[x:.*]]: !llvm.ptr)
func.func @opaque_pointers_atomic_rwu(%v: !llvm.ptr, %x: !llvm.ptr) {
  // CHECK: omp.atomic.read %[[v]] = %[[x]] : !llvm.ptr, i32
  // CHECK: %[[VAL:.*]] = llvm.load %[[x]] : !llvm.ptr -> i32
  // CHECK: omp.atomic.write %[[v]] = %[[VAL]] : !llvm.ptr, i32
  // CHECK: omp.atomic.update %[[x]] : !llvm.ptr {
  // CHECK-NEXT: ^{{[[:alnum:]]+}}(%[[XVAL:.*]]: i32):
  // CHECK-NEXT:   omp.yield(%[[XVAL]] : i32)
  // CHECK-NEXT: }
  omp.atomic.read %v = %x : !llvm.ptr, i32
  %val = llvm.load %x : !llvm.ptr -> i32
  omp.atomic.write %v = %val : !llvm.ptr, i32
  omp.atomic.update %x : !llvm.ptr {
    ^bb0(%xval: i32):
      omp.yield(%xval : i32)
  }
  return
}

// CHECK-LABEL: @opaque_pointers_reduction
// CHECK: atomic {
// CHECK-NEXT: ^{{[[:alnum:]]+}}(%{{.*}}: !llvm.ptr, %{{.*}}: !llvm.ptr):
omp.reduction.declare @opaque_pointers_reduction : f32
init {
^bb0(%arg: f32):
  %0 = arith.constant 0.0 : f32
  omp.yield (%0 : f32)
}
combiner {
^bb1(%arg0: f32, %arg1: f32):
  %1 = arith.addf %arg0, %arg1 : f32
  omp.yield (%1 : f32)
}
atomic {
^bb2(%arg2: !llvm.ptr, %arg3: !llvm.ptr):
  %2 = llvm.load %arg3 : !llvm.ptr -> f32
  llvm.atomicrmw fadd %arg2, %2 monotonic : !llvm.ptr, f32
  omp.yield
}

// CHECK-LABEL: omp_targets_with_map_bounds
// CHECK-SAME: (%[[ARG0:.*]]: !llvm.ptr, %[[ARG1:.*]]: !llvm.ptr)
func.func @omp_targets_with_map_bounds(%arg0: !llvm.ptr, %arg1: !llvm.ptr) -> () {
  // CHECK: %[[C_00:.*]] = llvm.mlir.constant(4 : index) : i64
  // CHECK: %[[C_01:.*]] = llvm.mlir.constant(1 : index) : i64
  // CHECK: %[[C_02:.*]] = llvm.mlir.constant(1 : index) : i64
  // CHECK: %[[C_03:.*]] = llvm.mlir.constant(1 : index) : i64
  // CHECK: %[[BOUNDS0:.*]] = omp.bounds   lower_bound(%[[C_01]] : i64) upper_bound(%[[C_00]] : i64) stride(%[[C_02]] : i64) start_idx(%[[C_03]] : i64)
  // CHECK: %[[MAP0:.*]] = omp.map_info var_ptr(%[[ARG0]] : !llvm.ptr, !llvm.array<10 x i32>)   map_clauses(tofrom) capture(ByRef) bounds(%[[BOUNDS0]]) -> !llvm.ptr {name = ""}
    %0 = llvm.mlir.constant(4 : index) : i64
    %1 = llvm.mlir.constant(1 : index) : i64
    %2 = llvm.mlir.constant(1 : index) : i64
    %3 = llvm.mlir.constant(1 : index) : i64
    %4 = omp.bounds   lower_bound(%1 : i64) upper_bound(%0 : i64) stride(%2 : i64) start_idx(%3 : i64)

    %mapv1 = omp.map_info var_ptr(%arg0 : !llvm.ptr, !llvm.array<10 x i32>)   map_clauses(tofrom) capture(ByRef) bounds(%4) -> !llvm.ptr {name = ""}
  // CHECK: %[[C_10:.*]] = llvm.mlir.constant(9 : index) : i64
  // CHECK: %[[C_11:.*]] = llvm.mlir.constant(1 : index) : i64
  // CHECK: %[[C_12:.*]] = llvm.mlir.constant(2 : index) : i64
  // CHECK: %[[C_13:.*]] = llvm.mlir.constant(2 : index) : i64
  // CHECK: %[[BOUNDS1:.*]] = omp.bounds   lower_bound(%[[C_11]] : i64) upper_bound(%[[C_10]] : i64) stride(%[[C_12]] : i64) start_idx(%[[C_13]] : i64)
  // CHECK: %[[MAP1:.*]] = omp.map_info var_ptr(%[[ARG1]] : !llvm.ptr, !llvm.array<10 x i32>)   map_clauses(exit_release_or_enter_alloc) capture(ByCopy) bounds(%[[BOUNDS1]]) -> !llvm.ptr {name = ""}
    %6 = llvm.mlir.constant(9 : index) : i64
    %7 = llvm.mlir.constant(1 : index) : i64
    %8 = llvm.mlir.constant(2 : index) : i64
    %9 = llvm.mlir.constant(2 : index) : i64
    %10 = omp.bounds   lower_bound(%7 : i64) upper_bound(%6 : i64) stride(%8 : i64) start_idx(%9 : i64)
    %mapv2 = omp.map_info var_ptr(%arg1 : !llvm.ptr, !llvm.array<10 x i32>)   map_clauses(exit_release_or_enter_alloc) capture(ByCopy) bounds(%10) -> !llvm.ptr {name = ""}

    // CHECK: omp.target map_entries(%[[MAP0]] -> {{.*}}, %[[MAP1]] -> {{.*}} : !llvm.ptr, !llvm.ptr)
    omp.target map_entries(%mapv1 -> %arg2, %mapv2 -> %arg3 : !llvm.ptr, !llvm.ptr) {
    ^bb0(%arg2: !llvm.ptr, %arg3: !llvm.ptr):
      omp.terminator
    }

    // CHECK: omp.target_data map_entries(%[[MAP0]], %[[MAP1]] : !llvm.ptr, !llvm.ptr)
    omp.target_data map_entries(%mapv1, %mapv2 : !llvm.ptr, !llvm.ptr){}

    // CHECK: %[[MAP2:.*]] = omp.map_info var_ptr(%[[ARG0]] : !llvm.ptr, !llvm.array<10 x i32>)   map_clauses(exit_release_or_enter_alloc) capture(VLAType) bounds(%[[BOUNDS0]]) -> !llvm.ptr {name = ""}
    // CHECK: omp.target_enter_data map_entries(%[[MAP2]] : !llvm.ptr)
    %mapv3 = omp.map_info var_ptr(%arg0 : !llvm.ptr, !llvm.array<10 x i32>)   map_clauses(exit_release_or_enter_alloc) capture(VLAType) bounds(%4) -> !llvm.ptr {name = ""}
    omp.target_enter_data map_entries(%mapv3 : !llvm.ptr){}

    // CHECK: %[[MAP3:.*]] = omp.map_info var_ptr(%[[ARG1]] : !llvm.ptr, !llvm.array<10 x i32>)   map_clauses(exit_release_or_enter_alloc) capture(This) bounds(%[[BOUNDS1]]) -> !llvm.ptr {name = ""}
    // CHECK: omp.target_exit_data map_entries(%[[MAP3]] : !llvm.ptr)
    %mapv4 = omp.map_info var_ptr(%arg1 : !llvm.ptr, !llvm.array<10 x i32>)   map_clauses(exit_release_or_enter_alloc) capture(This) bounds(%10) -> !llvm.ptr {name = ""}
    omp.target_exit_data map_entries(%mapv4 : !llvm.ptr){}

    return
}

// CHECK-LABEL: omp_target_update_data
func.func @omp_target_update_data (%if_cond : i1, %device : si32, %map1: memref<?xi32>, %map2: memref<?xi32>) -> () {
    %mapv_from = omp.map_info var_ptr(%map1 : memref<?xi32>, tensor<?xi32>) map_clauses(from) capture(ByRef) -> memref<?xi32> {name = ""}

    %mapv_to = omp.map_info var_ptr(%map2 : memref<?xi32>, tensor<?xi32>) map_clauses(present, to) capture(ByRef) -> memref<?xi32> {name = ""}

    // CHECK: omp.target_update_data if(%[[VAL_0:.*]] : i1) device(%[[VAL_1:.*]] : si32) nowait motion_entries(%{{.*}}, %{{.*}} : memref<?xi32>, memref<?xi32>)
    omp.target_update_data if(%if_cond : i1) device(%device : si32) nowait motion_entries(%mapv_from , %mapv_to : memref<?xi32>, memref<?xi32>)
    return
}

// CHECK-LABEL: omp_targets_is_allocatable
// CHECK-SAME: (%[[ARG0:.*]]: !llvm.ptr, %[[ARG1:.*]]: !llvm.ptr)
func.func @omp_targets_is_allocatable(%arg0: !llvm.ptr, %arg1: !llvm.ptr) -> () {
  // CHECK: %[[MAP0:.*]] = omp.map_info var_ptr(%[[ARG0]] : !llvm.ptr, i32) map_clauses(tofrom) capture(ByRef) -> !llvm.ptr {name = ""}  
  %mapv1 = omp.map_info var_ptr(%arg0 : !llvm.ptr, i32) map_clauses(tofrom) capture(ByRef) -> !llvm.ptr {name = ""}
  // CHECK: %[[MAP1:.*]] = omp.map_info var_ptr(%[[ARG1]] : !llvm.ptr, !llvm.struct<(ptr, i64, i32, i8, i8, i8, i8)>) map_clauses(tofrom) capture(ByRef) members(%[[MAP0]] : !llvm.ptr) -> !llvm.ptr {name = ""}
  %mapv2 = omp.map_info var_ptr(%arg1 : !llvm.ptr, !llvm.struct<(ptr, i64, i32, i8, i8, i8, i8)>)   map_clauses(tofrom) capture(ByRef) members(%mapv1 : !llvm.ptr) -> !llvm.ptr {name = ""}  
  // CHECK: omp.target map_entries(%[[MAP0]] -> {{.*}}, %[[MAP1]] -> {{.*}} : !llvm.ptr, !llvm.ptr)
  omp.target map_entries(%mapv1 -> %arg2, %mapv2 -> %arg3 : !llvm.ptr, !llvm.ptr) {
    ^bb0(%arg2: !llvm.ptr, %arg3 : !llvm.ptr):
      omp.terminator
  }
  return
}

// CHECK-LABEL: func @omp_target_enter_update_exit_data_depend
// CHECK-SAME:([[ARG0:%.*]]: memref<?xi32>, [[ARG1:%.*]]: memref<?xi32>, [[ARG2:%.*]]: memref<?xi32>) {
func.func @omp_target_enter_update_exit_data_depend(%a: memref<?xi32>, %b: memref<?xi32>, %c: memref<?xi32>) {
// CHECK-NEXT: [[MAP0:%.*]] = omp.map_info
// CHECK-NEXT: [[MAP1:%.*]] = omp.map_info
// CHECK-NEXT: [[MAP2:%.*]] = omp.map_info
  %map_a = omp.map_info var_ptr(%a: memref<?xi32>, tensor<?xi32>) map_clauses(to) capture(ByRef) -> memref<?xi32>
  %map_b = omp.map_info var_ptr(%b: memref<?xi32>, tensor<?xi32>) map_clauses(from) capture(ByRef) -> memref<?xi32>
  %map_c = omp.map_info var_ptr(%c: memref<?xi32>, tensor<?xi32>) map_clauses(exit_release_or_enter_alloc) capture(ByRef) -> memref<?xi32>

  // Do some work on the host that writes to 'a'
  omp.task depend(taskdependout -> %a : memref<?xi32>) {
    "test.foo"(%a) : (memref<?xi32>) -> ()
    omp.terminator
  }

  // Then map that over to the target
  // CHECK: omp.target_enter_data nowait map_entries([[MAP0]], [[MAP2]] : memref<?xi32>, memref<?xi32>) depend(taskdependin -> [[ARG0]] : memref<?xi32>)
  omp.target_enter_data nowait map_entries(%map_a, %map_c: memref<?xi32>, memref<?xi32>) depend(taskdependin ->  %a: memref<?xi32>)

  // Compute 'b' on the target and copy it back
  // CHECK: omp.target map_entries([[MAP1]] -> {{%.*}} : memref<?xi32>) {
  omp.target map_entries(%map_b -> %arg0 : memref<?xi32>) {
    ^bb0(%arg0: memref<?xi32>) :
      "test.foo"(%arg0) : (memref<?xi32>) -> ()
      omp.terminator
  }

  // Update 'a' on the host using 'b'
  omp.task depend(taskdependout -> %a: memref<?xi32>){
    "test.bar"(%a, %b) : (memref<?xi32>, memref<?xi32>) -> ()
  }

  // Copy the updated 'a' onto the target
  // CHECK: omp.target_update_data nowait motion_entries([[MAP0]] : memref<?xi32>) depend(taskdependin -> [[ARG0]] : memref<?xi32>)
  omp.target_update_data motion_entries(%map_a :  memref<?xi32>) depend(taskdependin -> %a : memref<?xi32>) nowait

  // Compute 'c' on the target and copy it back
  %map_c_from = omp.map_info var_ptr(%c: memref<?xi32>, tensor<?xi32>) map_clauses(from) capture(ByRef) -> memref<?xi32>
  omp.target map_entries(%map_a -> %arg0, %map_c_from -> %arg1 : memref<?xi32>, memref<?xi32>) depend(taskdependout -> %c : memref<?xi32>) {
  ^bb0(%arg0 : memref<?xi32>, %arg1 : memref<?xi32>) :
    "test.foobar"() : ()->()
    omp.terminator
  }
  // CHECK: omp.target_exit_data map_entries([[MAP2]] : memref<?xi32>) depend(taskdependin -> [[ARG2]] : memref<?xi32>)
  omp.target_exit_data map_entries(%map_c : memref<?xi32>) depend(taskdependin -> %c : memref<?xi32>)
  return
}
