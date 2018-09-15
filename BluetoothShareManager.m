//
//  BluetoothShareManager.m
//  BluetoothMacDemo
//
//  Created by UGEE_MAC on 2018/2/3.
//  Copyright © 2018年 UGEE_MAC. All rights reserved.
//

#import "BluetoothShareManager.h"
#import "BleDeviceModel.h"
#import "PenTabletMouseModel.h"

@interface BluetoothShareManager()<CBPeripheralDelegate,CBCentralManagerDelegate,CBPeripheralManagerDelegate>

//IOS蓝牙4.0中央管理器
@property (nonatomic,strong) CBCentralManager *mCentralManager;
//外设
@property (nonatomic,strong) CBPeripheral *mPeripheral;
//写入特征
@property (nonatomic,strong) CBCharacteristic *mCharacteristic;



@property (nonatomic,strong) NSMutableArray *peripheralArrays;
@property (nonatomic,strong) NSMutableDictionary *peripheralDict;

@property (nonatomic,strong) BleDeviceModel *mDeviceModel;

@end

@implementation BluetoothShareManager

+(instancetype) shareManager
{
    static BluetoothShareManager *manager = nil ;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[BluetoothShareManager alloc] init];
    });
    
    return manager;
}
-(void)setManageDelegate:(id) tempDelegate
{
    mDelegate = tempDelegate;
}

-(NSMutableArray *)peripheralArrays
{
    if(_peripheralArrays == nil)
    {
        _peripheralArrays = [[NSMutableArray alloc] init];
    }
    
    return _peripheralArrays;
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        [self startCentralManager];
        _mDeviceModel = [[BleDeviceModel alloc] init];
        _peripheralDict = [[NSMutableDictionary alloc] init];
        nameData = [[NSMutableData alloc] init];
    }
    
    return  self;
}

-(void)startCentralManager
{
    self.mCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}
    
-(void)ScanBlueToothDevice
{
    [self.mCentralManager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@false}];
}

-(void)StopSacenBleDevice
{
    [self.mCentralManager stopScan];
}
-(void)CancelDisconnectBlueToothDevice:(CBPeripheral*)peripheral;
{
    if(peripheral != nil)
    {
        [self.mCentralManager cancelPeripheralConnection:peripheral];
    }
}

-(void)ConnectBlueToothDevicePeripheral:(CBPeripheral *)peripheral
{
    
    [self.mCentralManager connectPeripheral:peripheral options:nil];
    
    [self.mCentralManager stopScan];
}
    
-(void)WriteBlueToothValue:(NSString*) writeValue
{
    if(self.mPeripheral.state == CBPeripheralStateConnected)
    {
        NSData *date = [writeValue dataUsingEncoding:NSUTF8StringEncoding];
        [self.mPeripheral writeValue:date forCharacteristic:self.mCharacteristic type:CBCharacteristicWriteWithResponse];
    }
}

 //2.发现和连接已经广播的外设设备

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case  CBCentralManagerStateResetting:
            
            break;
        case  CBCentralManagerStateUnsupported:
            break;
        case CBCentralManagerStateUnauthorized:
            break;
        case CBCentralManagerStatePoweredOff:
            break;
        case CBCentralManagerStatePoweredOn:
            break;
        default:
            break;
    }
    NSLog(@"centralManagerDidUpdateState:%ld",central.state);
    //_mCentralManager = central;

}

//3.查到外设后，停止扫描，连接设备

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    if (peripheral.name == nil) {
        return;
    }
    
    //[self.peripheralArrays addObject:peripheral];
    self.mCentralManager = central;
    
    if([mDelegate respondsToSelector:@selector(ScanBlueToothDevicePeripheral:advertisementData:)])
    {
        [mDelegate ScanBlueToothDevicePeripheral:peripheral advertisementData:advertisementData];
    }
    
    
    
    
    
}
//4.连接外设成功，开始发现服务
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
   
     self.mPeripheral = peripheral;
    if([mDelegate respondsToSelector:@selector(BlueToothDidConnectPeripheral:)])
    {
        [mDelegate BlueToothDidConnectPeripheral:peripheral];
    }
    
}

//连接外设失败
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if([mDelegate respondsToSelector:@selector(BlueToothDidFailToConnectPeripheral:error:)])
    {
        [mDelegate BlueToothDidFailToConnectPeripheral:peripheral error:error];
    }
}

//连接设备断开连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    NSLog(@"");
    
    if([mDelegate respondsToSelector:@selector(BlueToothDidDisconnectPeripheral:)])
    {
        [mDelegate BlueToothDidDisconnectPeripheral:peripheral];
    }
    
}



//连接外设成功后，显示服务列表
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    
    
    for (CBService *service in peripheral.services) {
        
        [peripheral discoverCharacteristics:nil forService:service];
    }
    
}

//6.已搜索到Characteristics
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(nonnull CBService *)service error:(nullable NSError *)error
{
    
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        NSLog(@"服务UUID:%@,特征UUID：%@,属性：%@",service.UUID,characteristic.UUID.UUIDString,characteristic);
        
         [peripheral readValueForCharacteristic:characteristic];
        
        if(characteristic.properties == CBCharacteristicPropertyNotify )
        {
            [peripheral setNotifyValue:true forCharacteristic:characteristic];
            
            
        }else if(characteristic.properties == CBCharacteristicPropertyWrite ||characteristic.properties == 0xc)
        {
            
            self.mCharacteristic = characteristic;
            //self.mPeripheral = peripheral;
            
        }
    }
}

//


 //8.获取外设发来的数据，不论是read和notify,获取数据都是从这个方法中读取
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    //处理数据 分配多种状态
    
//    if([mDelegate respondsToSelector:@selector(ReceiveBlueToothData:)])
//    {
//        [mDelegate ReceiveBlueToothData:characteristic.value];
//    }
    [self addData:characteristic.value];
    NSString *value = [NSString stringWithFormat:@"%@",characteristic.value];
    if (value == nil || value.length < 16)
    {
        return ;
    }
    NSMutableString *macString = [[NSMutableString alloc] init];
    
    [macString appendString:[[value substringWithRange:NSMakeRange(16, 2)] uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(14, 2)] uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(12, 2)] uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(5, 2)] uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(3, 2)] uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(1, 2)] uppercaseString]];
    //NSLog(@"mac == %@",macString);
    
    if ([mDelegate respondsToSelector:@selector(manager:didReceviceBleDeviceMacAddress:)]) {
        
        [mDelegate manager:self didReceviceBleDeviceMacAddress:macString];
    }
   

}

//9.用于检测中心向外设写数据是否成功
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error != nil)
    {
        NSLog(@"发送数据失败");
    }else
    {
       // NSLog(@"发送数据成功");
    }
}

-(void)addData:(NSData*) data
{
    unsigned char *bData = (unsigned char *)[data bytes];
    int    DataLen = (int)data.length;

    
    
    unsigned char bytes[10] = {0};
    int byteIndex = 0;
    for(int i=0 ; i < DataLen;i+=10)
    {
        //printf(" %x ",bData[i]);
        //bytes[byteIndex] = bData[i];
        
        memcpy(bytes, &bData[i], 10);
        
        //byteIndex++;
       // if((i+1)%10 == 0 && i>0)
       // {
            //printf("\n");
            
            if (bytes[0] == 0xfd&& bytes[0x2] != 0x4)
            {
                 if (bytes[3] == 0xf0&&bytes[4] == 0x0)
                 {
                     if ([mDelegate respondsToSelector:@selector(manager:didReceviceHotKeyDataPacket:status:)]) {
                         
                         [mDelegate manager:self didReceviceHotKeyDataPacket:bytes[5] status:(bytes[5] & 0x1)];
                     }
                 }
                else
                {
                    [[PenTabletMouseModel shareInstance] onEventMouseHandle:0x1 data:bytes];
                    BLE_DATAPACKET *datePacket = [[PenTabletMouseModel shareInstance] getDatePacket];
                    if ([mDelegate respondsToSelector:@selector(manager:didReceviceDataPacket:)]) {
                        
                        [mDelegate manager:self didReceviceDataPacket:datePacket];
                    }
                }
                
                //NSLog(@"penstatus:%d",datePacket->penstatus);
            }else
            {
                [self handleBytesData:bytes];
            }
            memset(bytes, 0, 10);
           // byteIndex = 0;
           
        //}
        
    }
}


//
-(void)handleBytesData:(unsigned char*) bytes
{
    switch (bytes[0x3]) {
        case 0xf2://获取电量
        {
            break;
        }
        //设置蓝牙设备显示名称(移动蓝牙和PC) (output)
        case 0x30://开始更新
        {
            break;
        }
        case 0x31://确认提交更新
        {
            break;
        }
        case 0x32://读取蓝牙显示名称(input)
        {
            int len = strlen(mDeviceInfo.product);
            for (int i = 0; i<4; i++)
            {
                mDeviceInfo.product[len+i] = bytes[5+i];
            }
            
            
            NSString *nameStr = [[NSString alloc] initWithBytes:mDeviceInfo.product length:32 encoding:NSUTF8StringEncoding];
           // NSLog(@"name:%@",nameStr);
            
            break;
        }
        case 0x11://读取设备串号(ID号)
        {
            int len = strlen(mDeviceInfo.serialnum);
            for (int i = 0; i<4; i++)
            {
                mDeviceInfo.serialnum[len+i] = bytes[5+i];
            }
            
            
            NSString *serialnumStr = [[NSString alloc] initWithBytes:mDeviceInfo.serialnum length:32 encoding:NSUTF8StringEncoding];
            //NSLog(@"serialnumStr:%@",serialnumStr);
            
            break;
        }
        case 0x64://读取蓝牙设备范围值
        {
            mDeviceInfo.axisX.max = *(unsigned short*)&bytes[4]; //x
            mDeviceInfo.axisY.max = *(unsigned short*)&bytes[0x6]; //y
            mDeviceInfo.pressure = *(unsigned short*)&bytes[8];
            // NSLog(@"pressure:%ld",mDeviceInfo.pressure);
            break;
        }
        case 0x5a://设备连接通知
        {
            [self sendAllCommand];
            break;
        }
        default:
            break;
    }
    
}

-(void)writeValue:(NSData*)sendValue
{
    if (self.mPeripheral != nil && self.mCharacteristic != nil)
    {
        [self.mPeripheral writeValue:sendValue forCharacteristic:_mCharacteristic type:CBCharacteristicWriteWithResponse];
    }
    
    
}


-(void)sendAllCommand
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self sendGetDeviceNameCommand:NULL length:0];
        
        [self sendGetPressureCommand:NULL  length:0];
        
        [self sendGetBleDeviceSerialNumber:NULL  length:0];
    });
    
}

-(void)bleGetDeviceInfo:(BLE_TABLET_DEVICEINFO*) lpDeviceInfo
{
    memcpy(lpDeviceInfo, &mDeviceInfo, sizeof(BLE_TABLET_DEVICEINFO));
}

-(void)sendGetDeviceNameCommand:(unsigned char*) bytes length:(int)dataLen
{
    if (bytes != NULL)
    {
        NSData *data = [[NSData alloc] initWithBytes:bytes length:dataLen];
        [self writeValue:data];
    }
    else
    {
        //读取蓝牙显示名称
        unsigned char bleName[11] = {0};
        bleName[0] = 0x04;
        bleName[1] = 0x32;
        for (int i = 0; i< 3; i++)
        {
            bleName[2] = (i*4<<4) + 0;
            
            NSData *data = [[NSData alloc] initWithBytes:bleName length:11];
            [self writeValue:data];
        }
    }
    
    
   
}



-(void)setBleDeviceName:(NSString*) deviceName
{
    
}

-(void)sendGetPressureCommand:(unsigned char*) bytes length:(int)dataLen
{
    if (bytes != NULL)
    {
        NSData *data = [[NSData alloc] initWithBytes:bytes length:dataLen];
        [self writeValue:data];
    }
    else
    {
        unsigned char bleName[11] = {0};
        bleName[0] = 0x04;
        bleName[1] = 0x64;
        
       NSData *data = [[NSData alloc] initWithBytes:bleName length:11];
        [self writeValue:data];
    }
    
}

-(void)sendGetBleDeviceSerialNumber:(unsigned char*) bytes length:(int)dataLen
{
    if (bytes != NULL)
    {
        NSData *data = [[NSData alloc] initWithBytes:bytes length:dataLen];
        [self writeValue:data];
    }
    else
    {
        unsigned char bleName[11] = {0};
        bleName[0] = 0x04;
        bleName[1] = 0x11;
        
        for (int i = 0; i< 3; i++)
        {
            bleName[2] = (i*4<<4) + 0;
            
            NSData *data = [[NSData alloc] initWithBytes:bleName length:11];
            [self writeValue:data];
        }
    }
}


@end
