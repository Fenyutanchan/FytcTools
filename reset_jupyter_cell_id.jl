# Copyright (c) 2025 Quan-feng WU <wuquanfeng@ihep.ac.cn>
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

for file_name ∈ ARGS
    isfile(file_name) || continue

    contents = readlines(file_name)
    id_indices = findall(contains("\"id\":"), contents)
    for id_index ∈ id_indices
        id_line = contents[id_index]
        contents[id_index] = replace(id_line,
            string(match(r"[0-9a-f]{8}", id_line, 1).match) =>
                string(rand(range(0, 0xffffffff)); base=16, pad=8)
        )
    end

    write(file_name, join(contents, '\n'))
    println("Re-geenerated IDs in file: $file_name")
end
