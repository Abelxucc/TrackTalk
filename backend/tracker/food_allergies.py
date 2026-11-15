import re
from unicodedata import normalize

from django.views.decorators.cache import never_cache
from rest_framework import serializers
from rest_framework.authentication import TokenAuthentication
from rest_framework.decorators import api_view, authentication_classes, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import FoodAllergySettings


# UK Food Standards Agency: the 14 allergens covered by UK food labelling.
ALLERGENS = {
    "milk": "Milk",
    "eggs": "Eggs",
    "peanuts": "Peanuts",
    "tree_nuts": "Tree nuts",
    "gluten_cereals": "Gluten cereals (e.g. wheat, oats)",
    "soya": "Soya",
    "sesame": "Sesame",
    "fish": "Fish",
    "crustaceans": "Crustaceans (e.g. prawns)",
    "molluscs": "Molluscs (e.g. mussels)",
    "celery": "Celery",
    "mustard": "Mustard",
    "lupin": "Lupin",
    "sulphites": "Sulphur dioxide & sulphites",
}


def food_name_key(name):
    return " ".join(re.findall(r"[^\W_]+", normalize("NFKC", name).casefold()))


class FoodAllergiesInput(serializers.Serializer):
    allergen_ids = serializers.ListField(
        child=serializers.ChoiceField(choices=tuple(ALLERGENS)),
        max_length=len(ALLERGENS),
    )
    other_foods = serializers.ListField(
        child=serializers.CharField(max_length=80),
        max_length=50,
    )

    def validate_allergen_ids(self, value):
        return [allergen for allergen in ALLERGENS if allergen in value]

    def validate_other_foods(self, value):
        foods = {}
        for food in value:
            name = " ".join(food.split())
            key = food_name_key(name)
            if not any(character.isalpha() for character in key):
                raise serializers.ValidationError("Enter a food name.")
            foods.setdefault(key, name)
        return list(foods.values())


def saved_allergies(user_id):
    return FoodAllergySettings.objects.filter(user_id=user_id).values_list(
        "allergen_ids", "other_foods",
    ).first() or ([], [])


@never_cache
@api_view(["GET", "PUT"])
@authentication_classes([TokenAuthentication])
@permission_classes([IsAuthenticated])
def food_allergies(request):
    if request.method == "PUT":
        serializer = FoodAllergiesInput(data=request.data)
        serializer.is_valid(raise_exception=True)
        settings, _ = FoodAllergySettings.objects.update_or_create(
            user=request.user, defaults=serializer.validated_data,
        )
        allergen_ids, other_foods = settings.allergen_ids, settings.other_foods
    else:
        allergen_ids, other_foods = saved_allergies(request.user.pk)
    return Response({
        "options": [{"id": key, "label": label} for key, label in ALLERGENS.items()],
        "allergen_ids": allergen_ids,
        "other_foods": other_foods,
    })
