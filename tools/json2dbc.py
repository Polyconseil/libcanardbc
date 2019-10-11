#!/usr/bin/env python3.7

import argparse
import dataclasses
import json
import textwrap
import typing


@dataclasses.dataclass
class SignalValue:
    name: str
    value: int

    @staticmethod
    def from_json(key, value):
        return SignalValue(value, int(key))

    def to_dbc(self):
        return f'{self.value} "{self.name}"'


@dataclasses.dataclass
class SignalValueDefinition:
    can_id: int
    signal_name: str
    signal_values: typing.List[SignalValue]

    def to_dbc(self):
        value_table_definition = ' '.join(signal_value.to_dbc() for signal_value in self.signal_values)
        return f'VAL_ {self.can_id} {self.signal_name} {value_table_definition};'


@dataclasses.dataclass
class Signal:
    name: str
    bit_start: int
    length: int
    little_endian: bool
    signed: bool
    value_type: str
    factor: float = 1.0
    offset: float = 0.0
    min: float = 0.0
    max: float = 0.0
    is_multiplexor: bool = False
    multiplexor_id: typing.Optional[int] = None
    unit: str = ""
    values: typing.List[SignalValue] = dataclasses.field(default_factory=list)
    receiving_nodes: typing.List[str] = dataclasses.field(default_factory=list)

    @staticmethod
    def from_json(key, value):
        values = [SignalValue.from_json(key, value) for key, value in value.get('enums', {}).items()]
        return Signal(
            key,
            value['bit_start'],
            value['length'],
            value['little_endian'],
            value['signed'],
            value['value_type'],
            value['factor'],
            value['offset'],
            value['min'],
            value['max'],
            value.get('multiplexor', False),
            value.get('multiplexing'),
            value.get('unit', ""),
            values,
        )

    def to_dbc(self):
        little_endian = 1 if self.little_endian else 0
        signed = '-' if self.signed else '+'
        receiving_nodes = ','.join(self.receiving_nodes) if self.receiving_nodes else 'Vector__XXX'
        multiplexor_info = ''
        if self.is_multiplexor:
            multiplexor_info = ' M'
        elif self.multiplexor_id is not None:
            multiplexor_info = f' m{self.multiplexor_id}'
        return f' SG_ {self.name}{multiplexor_info} : {self.bit_start}|{self.length}@{little_endian}{signed} '\
            f'({self.factor:g},{self.offset:g}) [{self.min:g}|{self.max:.64g}] "{self.unit}" {receiving_nodes}'


@dataclasses.dataclass
class Message:
    can_id: int
    name: str
    sending_node: str
    length: int  # in bytes
    signals: typing.List[Signal]

    def __post_init__(self):
        assert self.name.strip() != ""
        assert self.sending_node.strip() != ""

    @staticmethod
    def from_json(key, value):
        signals = []
        for signal_key, signal_value in value.get('signals', {}).items():
            signals.append(Signal.from_json(signal_key, signal_value))

        return Message(key, value['name'], value['sender'], value['length'], signals)

    def to_dbc(self):
        signals = [signal.to_dbc() for signal in self.signals]
        dbc_lines = [f'BO_ {self.can_id} {self.name}: {self.length} {self.sending_node}'] + signals
        return '\n'.join(dbc_lines)


@dataclasses.dataclass
class Database:
    version: str
    messages: typing.List[Message]
    nodes: typing.Set[str] = dataclasses.field(default_factory=set)
    signal_value_definitions: typing.List[SignalValueDefinition] = dataclasses.field(default_factory=list)
    attribute_definitions: typing.Any = None  # Not implemented yet

    def __post_init__(self):
        self.nodes = {message.sending_node for message in self.messages if message.sending_node}
        for message in self.messages:
            for signal in message.signals:
                if signal.values:
                    self.signal_value_definitions.append(
                        SignalValueDefinition(message.can_id, signal.name, signal.values)
                    )

    @staticmethod
    def from_json(obj):
        messages = []
        for key, value in obj.get('messages', {}).items():
            messages.append(Message.from_json(key, value))
        return Database(obj.get('version', ''), messages)

    def to_dbc(self):
        messages = '\n'.join(message.to_dbc() for message in self.messages) + '\n'
        nodes = ' ' + ' '.join(node for node in self.nodes)
        signal_value_definitions = '\n'.join(
            signal_value_def.to_dbc() for signal_value_def in self.signal_value_definitions
        )
        dbc = textwrap.dedent(f"""\
        VERSION "{self.version}"

        NS_ :
            BA_
            BA_DEF_
            BA_DEF_DEF_
            BA_DEF_DEF_REL_
            BA_DEF_REL_
            BA_DEF_SGTYPE_
            BA_REL_
            BA_SGTYPE_
            BO_TX_BU_
            BU_BO_REL_
            BU_EV_REL_
            BU_SG_REL_
            CAT_
            CAT_DEF_
            CM_
            ENVVAR_DATA_
            EV_DATA_
            FILTER
            NS_DESC_
            SGTYPE_
            SGTYPE_VAL_
            SG_MUL_VAL_
            SIGTYPE_VALTYPE_
            SIG_GROUP_
            SIG_TYPE_REF_
            SIG_VALTYPE_
            VAL_
            VAL_TABLE_

        BS_:
        BU_:{nodes}
        """)
        dbc += messages + '\n'
        dbc += textwrap.dedent("""\
        BA_DEF_ BO_ "isj1939dbc" INT 0 0;
        BA_DEF_ BO_ "GenMsgBackgroundColor" STRING ;
        BA_DEF_ BO_ "GenMsgForegroundColor" STRING ;
        BA_DEF_DEF_ "isj1939dbc" 0;
        BA_DEF_DEF_ "GenMsgBackgroundColor" "#ffffff";
        BA_DEF_DEF_ "GenMsgForegroundColor" "#000000";
        """) + '\n'
        dbc += signal_value_definitions
        return dbc


def main():
    parser = argparse.ArgumentParser(description="Convert JSON to DBC.")
    parser.add_argument('path', help="Path to JSON input file")
    args = parser.parse_args()

    with open(args.path, encoding='utf-8', mode='r') as json_file:
        json_obj = json.load(json_file)
        print(Database.from_json(json_obj).to_dbc())


if __name__ == '__main__':
    main()
