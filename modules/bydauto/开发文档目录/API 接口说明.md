比亚迪致力于构建开放、共赢的智能汽车生态，为广大应用开发者提供了专业的车机应用接入平台。开发者可充分利用比亚迪提供的丰富系统资源与标准化的车机开放接口（API），高效开发并深度适配适用于比亚迪智能座舱的应用程序。

开放API内容包括：车身、行驶数据、车速、能力模式、全景、空调、 PM2.5、雷达、充电设备、车辆设置等 18 类数据。

各模块主要通过get、set、监听三种方式开放数据。

get 用于获取车辆状态数据， set 用于控制车辆和更改车辆设置项， 监听可以实时获取各模块数据的变化。

其中 set 接口的返回值，仅表示命令下发是否成功，需要通过监听接口确定设置是否成功。

## **API 接口说明**

## **1.调用流程**

**以空调类说明：**

**（1）AndroidManifest.xml 声明权限**

<uses-permissionandroid:name="android.permission.BYDAUTO_AC_COMMON"/>

当调用 getXxx()接口时需要添加以下权限：

<uses-permissionandroid:name="android.permission.BYDAUTO_AC_GET" />

当调用 setXxx()接口时需要添加以下权限：

<uses-permission android:name="android.permission.BYDAUTO_AC_SET" />

当调用媒体中心类接口 controlMedia 时需要另外加入以下权限：

<uses-permission

   android:name="com.byd.mediacenter.STARTSERVER"

   android:protectionLevel="signatureOrSystem"/>

其中 BYDAUTO_AC_COMMON 属于在代码中动态申请的权限。

目前只有空调类、车身类、门锁类、仪表类、全景影像类、设置类需要申请动态权限， 具体权限请参考 api 开发文档。

**（2）创建实例**

在创建实例之前需要动态申请获得 BYDAUTO_AC_COMMON 权限，否则整个类的所有接口都不能使用。

BYDAutoAcDevice bydAutoAcDevice = BYDAutoAcDevice.getInstance(mContext);

**（3）调用接口**

bydAutoAcDevice.start(BYDAutoAcDevice.AC_CTRL_SOURCE_VOICE);

**（4）注册监听**

bydAutoAcDevice.registerListener(absBYDAutoAcListener);

AbsBYDAutoAcListener absBYDAutoAcListener = new AbsBYDAutoAcListener()

   { @Override

       public void onAcStarted() {

           super.onAcStarted();

       }

   @Override

       public void onAcStoped() {

           super.onAcStoped();

       }

   @Override

       public void onAcOnlineStateChanged(int state)

            { super.onAcOnlineStateChanged(state);

   }

   @Override

       public void onAcRearStarted()

            { super.onAcRearStarted();

   }

   @Override

       public void onAcRearStoped()

           { super.onAcRearStoped();

   }

   @Override

       public void onAcCtrlModeChanged(int mode) {

           super.onAcCtrlModeChanged(mode);

   }

   @Override

       public void onAcCycleModeChanged(int mode)

           { super.onAcCycleModeChanged(mode);

   }

   @Override

       public void onAcVentilationStateChanged(int state)

           { super.onAcVentilationStateChanged(state);

   }

   @Override

       public void onAcTemperatureControlModeChanged(int mode)

           { super.onAcTemperatureControlModeChanged(mode);

   }

**（5）取消监听**

bydAutoAcDevice.unregisterListener(absBYDAutoAcListener);

## **2.注意事项**

（1）由于各车型配置不同、电源档位不同， 某些接口不能正确返回。 set 接口建议在 ON 档电下操作。

（2）接口实际的输入输出以公开的 JAR包为准。

（3）若非实车测试，因未发报文或者报文值错误的场景下，部分接口可能会返回默认值65535。

（4）API参数的描述，表达的范围是有效的数据范围。在非实车环境未发报文的场景下，可能会返回描述之外的值。

## **键值说明**

车内转向盘开关可以控制车载多媒体部分功能， 开放以下三个健值供开发者使用。

| 键名                     | 描述         |
| ------------------------ | ------------ |
| KEYCODE_MEDIA_PREVIOUS   | 上一首       |
| KEYCODE_MEDIA_NEXT       | 下一首       |
| KEYCODE_AUTO_MEDIA_VOICE | 激活语音功能 |

表 1-1 键值说明

## **其他说明**

1、获取 GPS 信息请参考标准安卓接口

2、获取音量信息请参考标准安卓接口

3、调用车机接口 APK 需要系统签名才能安装运行

4、部分车型有摄像头配置，包括行车记录仪摄像头(车外影像)、顶灯摄像头(车内影像)，开发者如果需要获取摄像头影像信息，可调用安卓 Camera 标准接口。不同摄像头可用cameraId 区分。

| 摄像头类型       | id  |
| ---------------- | --- |
| 行车记录仪摄像头 | 0   |
| 顶灯摄像头       | 1   |
