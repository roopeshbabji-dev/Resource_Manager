class UserModel {
  final String id;
  final String name;
  final String email;
  final String passwordHash;
  final String passwordSalt;
  final String createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      passwordHash: map['passwordHash'] as String,
      passwordSalt: map['passwordSalt'] as String,
      createdAt: map['createdAt'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'passwordHash': passwordHash,
    'passwordSalt': passwordSalt,
    'createdAt': createdAt,
  };
}

class HouseholdMember {
  final String id;
  final String userId;
  final String name;
  final String relationship;
  final String? avatar;

  HouseholdMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.relationship,
    this.avatar,
  });

  factory HouseholdMember.fromMap(Map<String, dynamic> map) => HouseholdMember(
    id: map['id'] as String,
    userId: map['userId'] as String,
    name: map['name'] as String,
    relationship: map['relationship'] as String,
    avatar: map['avatar'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'relationship': relationship,
    'avatar': avatar,
  };
}

class ResourceModel {
  final String id;
  final String userId;
  final String name;
  final String category;
  final String unit;
  final String iconName;
  final String color;
  final String createdAt;

  ResourceModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.unit,
    required this.iconName,
    required this.color,
    required this.createdAt,
  });

  factory ResourceModel.fromMap(Map<String, dynamic> map) => ResourceModel(
    id: map['id'] as String,
    userId: map['userId'] as String,
    name: map['name'] as String,
    category: map['category'] as String,
    unit: map['unit'] as String,
    iconName: map['iconName'] as String,
    color: map['color'] as String,
    createdAt: map['createdAt'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'category': category,
    'unit': unit,
    'iconName': iconName,
    'color': color,
    'createdAt': createdAt,
  };
}

class ResourceUsage {
  final String id;
  final String userId;
  final String resourceId;
  final double quantity;
  final String unit;
  final DateTime date;
  final double cost;
  final String notes;

  ResourceUsage({
    required this.id,
    required this.userId,
    required this.resourceId,
    required this.quantity,
    required this.unit,
    required this.date,
    required this.cost,
    required this.notes,
  });

  factory ResourceUsage.fromMap(Map<String, dynamic> map) => ResourceUsage(
    id: map['id'] as String,
    userId: map['userId'] as String,
    resourceId: map['resourceId'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    unit: map['unit'] as String,
    date: DateTime.parse(map['date'] as String),
    cost: (map['cost'] as num).toDouble(),
    notes: map['notes'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'resourceId': resourceId,
    'quantity': quantity,
    'unit': unit,
    'date': date.toIso8601String(),
    'cost': cost,
    'notes': notes,
  };
}

class Expense {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final String paymentMethod;
  final String notes;
  final bool recurring;

  Expense({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.paymentMethod,
    required this.notes,
    required this.recurring,
  });

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as String,
    userId: map['userId'] as String,
    title: map['title'] as String,
    amount: (map['amount'] as num).toDouble(),
    category: map['category'] as String,
    date: DateTime.parse(map['date'] as String),
    paymentMethod: map['paymentMethod'] as String,
    notes: map['notes'] as String? ?? '',
    recurring: (map['recurring'] as int) == 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'amount': amount,
    'category': category,
    'date': date.toIso8601String(),
    'paymentMethod': paymentMethod,
    'notes': notes,
    'recurring': recurring ? 1 : 0,
  };
}

class InventoryItem {
  final String id;
  final String userId;
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final double minimumStock;
  final double price;
  final DateTime purchaseDate;
  final DateTime? expiryDate;
  final String notes;

  InventoryItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.minimumStock,
    required this.price,
    required this.purchaseDate,
    this.expiryDate,
    required this.notes,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) => InventoryItem(
    id: map['id'] as String,
    userId: map['userId'] as String,
    name: map['name'] as String,
    category: map['category'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    unit: map['unit'] as String,
    minimumStock: (map['minimumStock'] as num).toDouble(),
    price: (map['price'] as num).toDouble(),
    purchaseDate: DateTime.parse(map['purchaseDate'] as String),
    expiryDate: map['expiryDate'] == null
        ? null
        : DateTime.parse(map['expiryDate'] as String),
    notes: map['notes'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'name': name,
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'minimumStock': minimumStock,
    'price': price,
    'purchaseDate': purchaseDate.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'notes': notes,
  };
}

class ReminderModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime dueDate;
  final String time;
  final String recurring;
  final bool completed;

  ReminderModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.time,
    required this.recurring,
    required this.completed,
  });

  factory ReminderModel.fromMap(Map<String, dynamic> map) => ReminderModel(
    id: map['id'] as String,
    userId: map['userId'] as String,
    title: map['title'] as String,
    description: map['description'] as String,
    dueDate: DateTime.parse(map['dueDate'] as String),
    time: map['time'] as String,
    recurring: map['recurring'] as String,
    completed: (map['completed'] as int) == 1,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'dueDate': dueDate.toIso8601String(),
    'time': time,
    'recurring': recurring,
    'completed': completed ? 1 : 0,
  };
}

class AppSetting {
  final String key;
  final String value;

  AppSetting({required this.key, required this.value});

  factory AppSetting.fromMap(Map<String, dynamic> map) =>
      AppSetting(key: map['key'] as String, value: map['value'] as String);

  Map<String, dynamic> toMap() => {'key': key, 'value': value};
}
