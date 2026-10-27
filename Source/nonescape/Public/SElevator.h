//============================================================================
//
//	Autor: BAYAR SEMIH
//
//  file: SElevator.h
//
//============================================================================
#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "Components/TimelineComponent.h"
#include "SElevator.generated.h"

UCLASS()
class NONESCAPE_API ASElevator : public AActor
{
	GENERATED_BODY()
	
public:	
	// Sets default values for this actor's properties
	ASElevator();

protected:
	// Called when the game starts or when spawned
	virtual void BeginPlay() override;

	UPROPERTY(VisibleAnywhere)
	TObjectPtr<UStaticMeshComponent> ElevatorMesh;

	UPROPERTY(VisibleAnywhere, Category="Elevator")
	TObjectPtr<UTimelineComponent> ElevatorTimeline;
	
	UPROPERTY(EditAnywhere, Category="Elevator")
	TObjectPtr<UCurveFloat> ElevatorCurve;
	
	FVector StartLocation;
	UPROPERTY(EditAnywhere, Category="Elevator")
	FVector TargetLocation;
	

public:	
	// Called every frame
	virtual void Tick(float DeltaTime) override;

	FOnTimelineFloat ProgressFunction;
	
	UFUNCTION()
	void HandleProgress(float Value);

	
	UFUNCTION(BlueprintCallable, Category = "Elevator")
	void StartElevator();
};

