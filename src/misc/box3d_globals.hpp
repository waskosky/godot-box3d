#pragma once

// Extension-wide lifecycle hooks.

void box3d_initialize();

void box3d_deinitialize();

// The physics/box3d/worker_count setting, or the detected core count when it is 0 (auto).
int box3d_worker_count();
