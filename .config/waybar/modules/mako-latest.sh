
#!/bin/bash

latest=$(makoctl list | jq -r '.[0] | select(.summary != null) | .summary' 2>/dev/null)

if [[ -z "$latest" ]]; then
  echo "No notifications"
else
  # 長すぎると邪魔なので省略
  echo "${latest:0:30}"
fi
