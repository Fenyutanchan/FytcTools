# Copyright (c) 2025 Quan-feng WU <wuquanfeng@ihep.ac.cn>
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

import Pkg

Pkg.activate(@__DIR__)
Pkg.resolve()
Pkg.instantiate()

try
    using HTTP
catch
    Pkg.add("HTTP")
    using HTTP
end

try
    using JSON
catch
    Pkg.add("JSON")
    using JSON
end

function get_citation_key_list(tex_file::String)::Vector{String}
    @assert isfile(tex_file) "file not found: $tex_file"

    citation_key_list = String[]

    content = read(tex_file, String)
    content = replace(content, '\n' => "", '\t' => "", ' ' => "")

    for key_range ∈ findall(r"\\(full)?cite(\[.*?\])?\{.*?\}", content)
        tmp_string = content[key_range]
        tmp_range = (last ∘ findall)(r"\{.*?\}", tmp_string)
        key_string = tmp_string[first(tmp_range)+1:last(tmp_range)-1]
        append!(citation_key_list, split(key_string, ","))
    end

    unique!(citation_key_list)
    return citation_key_list
end
get_citation_key_list(tex_file_list::Vector{String})::Vector = isempty(tex_file_list) ? String[] : union(get_citation_key_list.(tex_file_list)...)

function get_inspirehep_bibtex(key::String)::String
    @info "Fetching bibtex for [$key] from inspirehep.net."

    page = num_page = 1
    bibtex_url = ""

    while page ≤ num_page
        json_url = "https://inspirehep.net/api/literature/?q=$(key)&page=$(page)"
        response = HTTP.request("GET", json_url)
        while response.status == 429
            @warn "Too many requests. Waiting for 5 seconds."
            sleep(5)
            response = HTTP.request("GET", json_url)
        end
        @assert response.status == 200 "Failed to fetch json from inspirehep.net: Code $(response.status) got."
        contents = (JSON.parse ∘ String)(response.body)
        num_literatures = contents["hits"]["total"]
        num_literatures == 0 && return ""
        literatures = contents["hits"]["hits"]
        num_page = ceil(Int, num_literatures / length(literatures))

        break_flag = false
        for literature ∈ literatures
            if key ∈ literature["metadata"]["texkeys"]
                bibtex_url = literature["links"]["bibtex"]
                break_flag = true
                break
            end
        end
        break_flag && break

        page += 1
    end

    response = HTTP.request("GET", bibtex_url)
    while response.status == 429
        @warn "Too many requests. Waiting for 5 seconds."
        sleep(5)
        response = HTTP.request("GET", url)
    end
    @assert response.status == 200 "Failed to fetch bibtex from inspirehep.net: Code $(response.status) got."
    bibtex_content = String(response.body)

    return bibtex_content
end

function get_inspirehep_bibtex(key_list::Vector{String})::String
    bibtex_contents = Vector{String}(undef, length(key_list))

    counter = Threads.Atomic{Int}(0)
    Threads.@threads for ii ∈ eachindex(key_list)
        bibtex_contents[ii] = get_inspirehep_bibtex(key_list[ii])
        Threads.atomic_add!(counter, 1)
        Threads.threadid() == 1 && @info "Progress: $(counter[]) / $(length(key_list))."
    end

    @info "All bibtex fetched."

    filter!(!isempty, bibtex_contents)

    return join(bibtex_contents, "\n")
end

function main(working_dir=pwd())
    tex_files = String[]
    for (this_dir, _, containing_files) ∈ walkdir(working_dir)
        if ".do_not_get_inspirehep_citations" ∈ containing_files
            @info "Skip `$(this_dir)` since `.do_not_get_inspirehep_citations` detected."
            continue
        end
        tex_files = union!(tex_files, filter(endswith(".tex"), containing_files))
        tex_files = joinpath.(this_dir, tex_files)
    end

    citation_key_list = get_citation_key_list(tex_files)

    others_bib_contents = try
        (String ∘ read)("others.bib")
    catch
        ""
    end
    filter!(!occursin(others_bib_contents), citation_key_list)

    @info "There are $(length(citation_key_list)) citation keys in total."
    bibtex_content = get_inspirehep_bibtex(citation_key_list)
    write("from_inspirehep.bib", bibtex_content)
end

main()
