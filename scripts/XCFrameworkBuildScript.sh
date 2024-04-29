export TERM=xterm-256color

#set -e表示一旦脚本中有命令的返回值为非0，则脚本立即退出，后续命令不再执行;
set -e
#set -o pipefail表示在管道连接的命令序列中，只要有任何一个命令返回非0值，则整个管道返回非0值，即使最后一个命令返回0.
set -o pipefail

#################[ 用于测试: 有助于在Xcode中解决一些基于构建环境的问题 ]########
#################[ Tests: helps workaround any future bugs in Xcode ]########
#
DEBUG_THIS_SCRIPT="true"

if [ $DEBUG_THIS_SCRIPT = "true" ]
then

#set -x表示显示所有执行命令信息;
set -x
echo "########### 用于测试/TESTS #############"
echo "BUILD_DIR = $BUILD_DIR"
echo "BUILD_ROOT = $BUILD_ROOT"
echo "CONFIGURATION_BUILD_DIR = $CONFIGURATION_BUILD_DIR"
echo "BUILT_PRODUCTS_DIR = $BUILT_PRODUCTS_DIR"
echo "CONFIGURATION_TEMP_DIR = $CONFIGURATION_TEMP_DIR"
echo "TARGET_BUILD_DIR = $TARGET_BUILD_DIR"
echo "SRCROOT = $SRCROOT"
echo "PROJECT_NAME = $PROJECT_NAME"
echo "TARGET_NAME = $TARGET_NAME"
echo "PRODUCT_NAME = $PRODUCT_NAME"
echo " "
fi

FRAMEWORK_NAME="$PRODUCT_NAME"
##FRAMEWORK_TYPE="project" # project or workspace
##FRAMEWORK_EXTENSION="xcodeproj" # xcodeproj or xcworkspace
FRAMEWORK_TYPE="workspace" # project or workspace
FRAMEWORK_EXTENSION="xcworkspace" # xcodeproj or xcworkspace

SCHEME_NAME="$FRAMEWORK_NAME"

ARCHIVE_PATH="./archives"
ARCHIVE_FRAMEWORK_PATH="Products/Library/Frameworks/$FRAMEWORK_NAME.framework"
PHYSICAL_DEVICES_ARCHIVE_PATH="$ARCHIVE_PATH/$FRAMEWORK_NAME.framework-iphoneos.xcarchive"
SIMULATED_DEVICES_ARCHIVE_PATH="$ARCHIVE_PATH/$FRAMEWORK_NAME.framework-iphonesimulator.xcarchive"
MAC_CATALYST_ARCHIVE_PATH="$ARCHIVE_PATH/$FRAMEWORK_NAME.framework-catalyst.xcarchive"

BUNDLE_SCHEME_NAME="$FRAMEWORK_NAME"Bundle
BUNDLE_PHYSICAL_DEVICES_ARCHIVE_PATH="$ARCHIVE_PATH/$FRAMEWORK_NAME.bundle-iphoneos.xcarchive"
ARCHIVE_BUNDLE_PATH="Products/Library/Bundles/$FRAMEWORK_NAME.bundle"

XCFRAMEWORK_OUTPUT_PATH="$ARCHIVE_PATH/xcframework"

restart() {
    clear && rm -rvf $ARCHIVE_PATH; mkdir $ARCHIVE_PATH
    echo "• [Restarted] - Success! •"
}


sliceForPhysicalDevices() {
    xcodebuild archive -$FRAMEWORK_TYPE "$FRAMEWORK_NAME.$FRAMEWORK_EXTENSION" \
    -scheme $SCHEME_NAME \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath $PHYSICAL_DEVICES_ARCHIVE_PATH SKIP_INSTALL=NO && \
    echo "• [Sliced] {Physical Devices} - Success! •"
}

sliceForSimulatedDevices() {
    xcodebuild archive -$FRAMEWORK_TYPE "$FRAMEWORK_NAME.$FRAMEWORK_EXTENSION" \
    -scheme $SCHEME_NAME \
    -configuration Release \
    -destination 'generic/platform=iOS Simulator' \
    -archivePath $SIMULATED_DEVICES_ARCHIVE_PATH SKIP_INSTALL=NO && \
    echo "• [Sliced] {Simulated Devices} - Success! •"
}

copyDependencies() {

    # 目录数组
    directories=()

    # 目标目录
    destination=$XCFRAMEWORK_OUTPUT_PATH


    # 遍历目录数组
    for dir in "${directories[@]}"; do
        # 搜索并复制xcframework文件到目标目录
        find "$dir" \( -name "*.xcframework" -o -name "*.bundle" \) -exec sh -xvc 'ditto "$0" "$1/$(basename $0)"' {} "$destination" \;
    done

    echo "• [Copy] {Copy Dependencies} - Success! •"
}

sliceForBundleDevice() {
    xcodebuild archive -$FRAMEWORK_TYPE "$FRAMEWORK_NAME.$FRAMEWORK_EXTENSION" \
    -scheme $BUNDLE_SCHEME_NAME \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath $BUNDLE_PHYSICAL_DEVICES_ARCHIVE_PATH SKIP_INSTALL=NO && \
    echo "• [Sliced] {Bundle Physical Devices} - Success! •"
}

copyBundle() {
    ditto "$BUNDLE_PHYSICAL_DEVICES_ARCHIVE_PATH/$ARCHIVE_BUNDLE_PATH" "$XCFRAMEWORK_OUTPUT_PATH/$FRAMEWORK_NAME.bundle"
    echo "• [Copy] {Copy bundle} - Success! •"
}

resolveBundles() {
    # 获取构建目录中所有的 bundle 目录
    bundle_dirs=$(ls -l "${XCFRAMEWORK_OUTPUT_PATH}" | grep '.bundle$' | awk '/^d/ {print $NF}')

    # 遍历每个 bundle 目录
    for bundle_dir in $bundle_dirs
    do
        # 获取 bundle 的可执行文件路径
        bundle_executable="${XCFRAMEWORK_OUTPUT_PATH}/${bundle_dir}/${bundle_dir%.*}"
        
        # 检查可执行文件是否存在，并删除
        if [ -f "${bundle_executable}" ]
        then
            echo "Remove bundle executable file: ${bundle_executable}"
            rm -rf "${bundle_executable}"
        fi
        
        # 删除 Info.plist 中的 Executable file 字段
        info_plist="${XCFRAMEWORK_OUTPUT_PATH}/${bundle_dir}/Info.plist"
        if [ -f "${info_plist}" ]
        then
            echo "Remove Executable file field from Info.plist: ${info_plist}"
            /usr/libexec/PlistBuddy -c "Delete :CFBundleExecutable" "${info_plist}"
        fi
    done

    echo "• [Resolve] {Resolve bundle} - Success! •"
}


createXCFrameworkExcludingAMacCatalystSlice() {
    sliceForPhysicalDevices && \
    sliceForSimulatedDevices && \
    xcodebuild -create-xcframework \
    -framework "$PHYSICAL_DEVICES_ARCHIVE_PATH/$ARCHIVE_FRAMEWORK_PATH" \
    -framework "$SIMULATED_DEVICES_ARCHIVE_PATH/$ARCHIVE_FRAMEWORK_PATH" \
    -output "$XCFRAMEWORK_OUTPUT_PATH/$FRAMEWORK_NAME.xcframework" && \
    #copyDependencies && \
    #sliceForBundleDevice && \
    #copyBundle && \
    #resolveBundles && \
    echo "• [XCFramework] {Created} - Success! •" && ls $XCFRAMEWORK_OUTPUT_PATH
}


buildExcludingMacCatalystSlice() {
    restart && \
    createXCFrameworkExcludingAMacCatalystSlice && \
    sleep 2 && clear && \
    echo "• [XCFramework] {Creation} - Completed! •" && echo "XCFramework Can Be Located At: $XCFRAMEWORK_OUTPUT_PATH": `ls $XCFRAMEWORK_OUTPUT_PATH` 
}


buildExcludingMacCatalystSlice
