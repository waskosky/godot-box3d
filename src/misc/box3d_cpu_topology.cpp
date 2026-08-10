#include "box3d_cpu_topology.hpp"

#include <box3d/constants.h>

#include <algorithm>
#include <thread>

#if defined(__APPLE__)
#include <sys/sysctl.h>
#elif defined(_WIN32)
#include <windows.h>

#include <vector>
#elif defined(__linux__)
#include <cstdio>
#include <cstdlib>
#include <set>
#include <string>
#endif

namespace {

#if defined(__APPLE__)

int detect_core_count() {
	int count = 0;
	size_t size = sizeof(count);
	if (sysctlbyname("hw.perflevel0.logicalcpu", &count, &size, nullptr, 0) == 0 && count > 0) {
		return count;
	}
	size = sizeof(count);
	if (sysctlbyname("hw.physicalcpu", &count, &size, nullptr, 0) == 0) {
		return count;
	}
	return 0;
}

#elif defined(_WIN32)

int detect_core_count() {
	DWORD size = 0;
	GetLogicalProcessorInformationEx(RelationProcessorCore, nullptr, &size);
	if (GetLastError() != ERROR_INSUFFICIENT_BUFFER || size == 0) {
		return 0;
	}
	std::vector<char> buffer(size);
	auto *info = reinterpret_cast<SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX *>(buffer.data());
	if (!GetLogicalProcessorInformationEx(RelationProcessorCore, info, &size)) {
		return 0;
	}
	int count = 0;
	DWORD offset = 0;
	while (offset < size) {
		const auto *entry =
				reinterpret_cast<const SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX *>(buffer.data() + offset);
		if (entry->Relationship == RelationProcessorCore) {
			count += 1;
		}
		offset += entry->Size;
	}
	return count;
}

#elif defined(__linux__)

int count_cpu_list(const char *p_text) {
	int count = 0;
	const char *cursor = p_text;
	while (*cursor != '\0') {
		char *end = nullptr;
		const long first = std::strtol(cursor, &end, 10);
		if (end == cursor) {
			break;
		}
		long last = first;
		if (*end == '-') {
			cursor = end + 1;
			last = std::strtol(cursor, &end, 10);
		}
		count += int(last - first + 1);
		if (*end != ',') {
			break;
		}
		cursor = end + 1;
	}
	return count;
}

int detect_core_count() {
	// Hybrid Intel lists P-cores here; the file does not exist on other CPUs.
	if (FILE *file = std::fopen("/sys/devices/cpu_core/cpus", "r")) {
		char line[256] = {};
		const bool read = std::fgets(line, sizeof(line), file) != nullptr;
		std::fclose(file);
		if (read) {
			const int count = count_cpu_list(line);
			if (count > 0) {
				return count;
			}
		}
	}
	// SMT siblings share one list string, so unique strings count physical cores.
	std::set<std::string> cores;
	for (int cpu = 0; cpu < 1024; cpu++) {
		char path[128];
		std::snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpu%d/topology/thread_siblings_list", cpu);
		FILE *file = std::fopen(path, "r");
		if (file == nullptr) {
			break;
		}
		char line[256] = {};
		if (std::fgets(line, sizeof(line), file) != nullptr) {
			cores.insert(line);
		}
		std::fclose(file);
	}
	return int(cores.size());
}

#else

int detect_core_count() {
	return 0;
}

#endif

} // namespace

int box3d_default_worker_count() {
	static const int count = []() {
		int detected = detect_core_count();
		if (detected <= 0) {
			detected = int(std::thread::hardware_concurrency() / 2);
		}
		return std::clamp(detected, 1, B3_MAX_WORKERS);
	}();
	return count;
}
