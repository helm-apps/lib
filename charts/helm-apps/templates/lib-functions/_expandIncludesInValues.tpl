{{/* The stuff below is complex and scary, and I can't make it simpler */}}

{{- define "lib.expandIncludesInValues" }}
{{-     $ := index . 0 }}
{{-     $location := index . 1 }}  {{/* Expand includes recursively starting here */}}
{{-     if kindIs "map" $location }}
{{-         include "lib._recursiveMergeAndExpandIncludes" (list $ $location) }}
{{-     else if kindIs "slice" $location }}
{{-         range $_, $locationNested := $location }}
{{-             include "lib.expandIncludesInValues" (list $ $locationNested) }}
{{-         end }}
{{-     end }}
{{- end }}



{{- define "lib._recursiveMergeAndExpandIncludes" }}
  {{- $ := index . 0 }}
  {{- $mergeInto := index . 1 }}

  {{- if kindIs "map" $mergeInto }}
    {{- if hasKey $mergeInto "_include" }}
      {{- $joinedIncludes := (include "lib._getJoinedIncludesInJson" (list $ $mergeInto._include) | fromJson).wrapper }}
      {{- $_ := unset $mergeInto "_include" }}
      {{- include "lib._recursiveMapsMerge" (list $ $joinedIncludes $mergeInto) }}
      {{- include "lib.expandIncludesInValues" (list $ $mergeInto) }}
    {{- else }}
      {{- range $nestedKey, $nestedVal := $mergeInto }}
        {{- if ne $nestedKey "_includes" }}
          {{- include "lib.expandIncludesInValues" (list $ $nestedVal) }}
        {{- end }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "lib._getJoinedIncludesInJson" }}
  {{- $ := index . 0 }}
  {{- $includesNames := index . 1 }}

  {{- $includesBodies := list }}
  {{- range $_, $includeName := $includesNames }}
    {{- $includesBodies = append $includesBodies (index $.Values.global._includes $includeName) }}
  {{- end }}

  {{- $joinedIncludesResult := dict }}
  {{- range $i, $includeBody := reverse $includesBodies }}
    {{- include "lib._recursiveMapsMerge" (list $ $includeBody $joinedIncludesResult) }}
  {{- end }}
  {{- dict "wrapper" $joinedIncludesResult | toJson }}
{{- end }}

{{- define "lib._recursiveMapsMerge" }}
  {{- $ := index . 0 }}
  {{- $mapToMergeFrom := index . 1 }}
  {{- if kindIs "map" $mapToMergeFrom }}
  {{- $mapToMergeFrom = deepCopy $mapToMergeFrom }}
  {{- end }}
  {{- $mapToMergeInto := index . 2 }}

  {{- range $keyToMergeFrom, $valToMergeFrom := $mapToMergeFrom }}
    {{- $valToMergeInto := index $mapToMergeInto $keyToMergeFrom }}

    {{- if kindIs "map" $valToMergeFrom }}
      {{- if kindIs "map" $valToMergeInto }}
        {{- if not (hasKey $mapToMergeFrom "_default") }}
        {{- include "lib._recursiveMapsMerge" (list $ $valToMergeFrom $valToMergeInto) }}
      {{- end }}
      {{- else if not (hasKey $mapToMergeInto $keyToMergeFrom) }}
        {{- $_ := set $mapToMergeInto $keyToMergeFrom $valToMergeFrom }}
      {{- end }}

    {{- else if kindIs "slice" $valToMergeFrom }}
      {{- if eq $keyToMergeFrom "_include" }}
        {{- if kindIs "slice" $valToMergeInto }}
          {{- $joinedIncludes := (include "lib._concatLists" (list $valToMergeFrom $valToMergeInto) | fromJson).wrapper }}
          {{- $_ := unset $mapToMergeInto "_include" }}
          {{- $_ := set $mapToMergeInto "_include" $joinedIncludes }}
        {{- else }}
          {{- $_ := unset $mapToMergeInto "_include" }}
          {{- $_ := set $mapToMergeInto "_include" $valToMergeFrom }}
        {{- end }}
      {{- end }}

    {{- else }}
      {{- if not (hasKey $mapToMergeInto $keyToMergeFrom) }}
        {{- $_ := set $mapToMergeInto $keyToMergeFrom $valToMergeFrom }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}

{{- define "lib._concatLists" }}
  {{- $lists := index . }}

  {{- $result := list }}
  {{- range $_, $list := $lists }}
    {{- range $_, $list_elem := $list }}
      {{- $result = append $result $list_elem }}
    {{- end }}
  {{- end }}
  {{- dict "wrapper" $result | toJson }}
{{- end }}


{{- define "_lib.make_includes_from" }}
{{-     $ := index . 0 }}
{{-     $prevContext := index . 1 }}
{{-     $curContext := index . 2 }}
{{-     $varName := index . 3 }}
{{-     if kindIs "map" $curContext }}
{{-         if hasKey $curContext "_include_from" }}
{{-             $includeVar := "" }}
{{-             $excludeParam := list }}
{{-             $includeParams := $curContext._include_from  }}
{{-             if kindIs "map" $includeParams }}
{{-                 $excludeParam = $curContext._include_from.exclude }}
{{-                 $includeVar = $curContext._include_from.path }}
{{-             else }}
{{-                 $includeVar = $curContext._include_from }}
{{-             end }}
{{-             $tmpMap := include "_getMapKeyValue" (list $.Values $includeVar) | fromJson }}
{{-             if gt (len $excludeParam) 0 }}
{{-                 range $e := $excludeParam }}
{{-                     $_ := unset $tmpMap $e }}
{{-                 end }}
{{-             end }}
{{-             $curContext := mergeOverwrite $curContext $tmpMap }}
{{-             $_ := set $prevContext $varName $curContext }}
{{-             $_ = unset $curContext "_include_from" }}
{{-         end }}
{{-         range $key,$varsDict := $curContext -}}
{{-             if kindIs "map" $varsDict -}}
{{-                 if gt (len $varsDict) 0 -}}
{{-                     include "_lib.make_includes_from" (list $ $curContext $varsDict $key) -}}
{{-                 end -}}
{{-             end -}}
{{-         end }}
{{-     end }}
{{- end }}

{{- define "_getMapKeyValue" }}
{{-     $map := index . 0 }}
{{-     $path := index . 1 }}
{{-     $tmpMap := $map }}
{{-     if contains "." $path  }}
{{-         $keys := regexSplit "\\." $path -1 }}
{{-         range $k := $keys }}
{{              if kindIs "map" $tmpMap  }}
{{-                 $tmpValue := get $tmpMap $k }}
{{-                 if kindIs "map" $tmpValue  }}
{{                      $tmpMap = $tmpValue }}
{{-                 else }}
{{                      fail $k }}
{{-                 end }}
{{-             end }}
{{-         end }}
{{-     else }}
{{-     $tmpMap = get $tmpMap $path }}
{{-     end }}
{{-     toJson $tmpMap }}
{{- end }}